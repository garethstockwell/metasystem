#!/usr/bin/env bash

# android-setup-ssh

# Configures an SSH daemon to run on the target, and configures adb to allow
# SSH over USB

# Requires a client/server version of dropbear to be installed.  While AOSP
# includes dropbear, this is (as of ICS) client-only.  CyanogenMod provides
# a version which includes an SSH server; to install this, use the following
# local manifest:

# <?xml version="1.0" encoding="UTF-8"?>
# <manifest>
#
#   <remote  name="github"
#            fetch="git://github.com/" />
#
#   <remove-project name="platform/external/dropbear" />
#   <project path="external/cm/dropbear"
#            name="CyanogenMod/android_external_dropbear"
#            remote="github"
#            revision="refs/heads/ics" />
#
# </manifest>


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

PASSWORD=password
REMOTE_SCRIPT_DIR=/data/bin
REMOTE_SSH_DIR=/data/dropbear/.ssh
DEFAULT_DROPBEAR=/system/xbin/dropbear


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_debug=no
opt_dropbear=$DEFAULT_DROPBEAR

for arg in $ARGUMENTS; do
	eval "arg_$arg="
done


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
	echo -e "\nError: $*"
	if [[ "$opt_dryrun" != yes ]]; then
		exit 1
	fi
}

function warn()
{
	echo "Warning: $*"
}

function usage_error()
{
	echo -e "Error: $*\n"
	print_usage
	exit 1
}

# Execute shell command; abort script if command fails
function execute()
{
	cmd="$*"
	[[ "$opt_verbosity" != silent ]] && echo -e "$cmd"
	if [[ "$opt_dryrun" != yes ]]; then
		$cmd
		r=$?
		[[ "$r" != 0 ]] && error Execution of \"$cmd\" failed: exit code $r
	fi
}

function print_rule()
{
	[[ "$opt_verbosity" != silent ]] && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [[ "$opt_verbosity" != silent ]]; then
		echo
		print_rule
		echo $*
		print_rule
	fi
}

function print_usage()
{
	cat << EOF
android-setup-ssh script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    source                  Source path
    dest                    Destination path

Options:
    -d, --debug             Do not remove temporary files
     --dropbear PATH        Location of dropbear binary (default $DEFAULT_DROPBEAR)
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

EOF
}

function print_version()
{
	cat << EOF
android-setup-ssh script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $*
	for token in "$@"; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-d | -debug | --debug)
				opt_debug=yes
				;;
			-h | -help | --help | -usage | --usage)
				opt_help=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				opt_verbosity=silent
				;;
			-v | -verbose | --verbose)
				opt_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				opt_dryrun=yes
				;;
			-V | -version | --version)
				opt_version=yes
				;;

			-dropbear | --dropbear)
				prev=opt_dropbear
				;;
			-dropbear=* | --dropbear=*)
				opt_dropbear=$optarg
				;;

			# Environment variables
			*=*)
				envvar=`expr "x$token" : 'x\([^=]*\)='`
				optarg=`echo "$optarg" | sed "s/'/'\\\\\\\\''/g"`
				eval "$envvar='$optarg'"
				export $envvar
				;;

			# Unrecognized options
			-*)
				warn "Unrecognized option '$token' ignored"
				;;

			# Normal arguments
			*)
				local arg_used=
				for arg in $ARGUMENTS; do
					if [[ -z `eval "echo \\$arg_$arg"` ]]; then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				[[ -z "$arg_used" ]] && warn "Additional argument '$token' ignored"
				;;
		esac
	done

	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $ARGUMENTS; do
		if [[ -z `eval "echo \\$arg_$arg"` ]]; then
			args_supplied=
			break
		fi
	done
	[[ -z "$args_supplied" ]] && usage_error 'Insufficient arguments provided'
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Debug ................................... $opt_debug
Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Target port ............................. $ANDROID_TARGET_SSH_PORT

Dropbear ................................ $opt_dropbear

EOF
	for arg in $ARGUMENTS; do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done
}

function set_script()
{
	local name=$1
	local remote_dir=$2
	script=$name
	local_script=$local_tmp_dir/$script
	remote_script=$REMOTE_SCRIPT_DIR/$script
}

function push_script()
{
	execute adb push $(nativepath $local_script) $remote_script
	execute adb shell "chmod 755 $remote_script"
}

function push_and_execute_script()
{
	push_script
	execute adb shell "$remote_script"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_command_line $args

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

print_banner Starting execution

[[ -z $ANDROID_TARGET_SSH_PORT ]] &&\
	error "ANDROID_TARGET_SSH_PORT is not set"

local_tmp_dir=$(mktemp -d)
echo -e "\nCreated local temporary directory $local_tmp_dir"

# Remount
print_banner Remounting R/W
execute adb root
execute adb remount
execute adb shell "mkdir -p $REMOTE_SCRIPT_DIR"

# Create keys
print_banner Creating keys
set_script ssh-create-keys.sh
dropbearkey=${opt_dropbear}key
remote_ssh_dir_parent=$(dirname $REMOTE_SSH_DIR)
cat >> $local_script << EOF
#!/system/bin/sh

ssh_dir=$REMOTE_SSH_DIR

mkdir -p \$ssh_dir
chmod 755 $remote_ssh_dir_parent
chmod 700 \$ssh_dir

authorized_keys=\$ssh_dir/authorized_keys
touch \$authorized_keys
chown root \$authorized_keys
chmod 600 \$authorized_keys

rsa_key=/data/dropbear/dropbear_rsa_host_key
dss_key=/data/dropbear/dropbear_dss_host_key
[[ ! -e \$rsa_key ]] && $dropbearkey -t rsa -f \$rsa_key
[[ ! -e \$dss_key ]] && $dropbearkey -t dss -f \$dss_key
EOF
push_and_execute_script

# Create start/stop script
print_banner Creating sshd.sh
set_script sshd.sh
cat >> $local_script << EOF
#!/system/bin/sh

case \$1 in
	start)
		echo "Starting dropbear ..."
		killall dropbear
		#cmd="$opt_dropbear -A -N root -U 0 -G 0 -C $PASSWORD -p $ANDROID_TARGET_SSH_PORT"
		cmd="$opt_dropbear -p $ANDROID_TARGET_SSH_PORT -F"
		echo \$cmd
		\$cmd
		;;

	stop)
		echo "Stopping dropbear ..."
		killall dropbear
		;;

	*)
		echo "Error: action '\$action' not supported" >&2
		exit 1
		;;
esac
EOF
push_script

# Push keys
print_banner Pushing public key
execute adb push $(nativepath ~/.ssh/id_rsa.pub) /data/id_rsa.pub
execute adb shell "cat /data/id_rsa.pub >> $REMOTE_SSH_DIR/authorized_keys"

# Start sshd
print_banner Starting sshd
if [[ $opt_dryrun != yes ]]; then
	nohup adb shell "$REMOTE_SCRIPT_DIR/sshd.sh start" >/dev/null 2&>/dev/null &
	echo -n "Waiting for SSH server to start ...    "
	interval=10
	start=$(date +%s)
    while true; do
        now=$(date +%s)
        remaining=$(($interval - $now + $start))
		processes=$(adb shell "ps | grep dropbear | grep -v grep")
        echo -en '\b\b\b'
        if [[ -n $processes ]]; then
            echo 'OK '
            break
        else
            if [[ $remaining > 0 ]]; then
                printf "%3d" $remaining
                sleep 1
            else
                echo 'timed out'
                exit 1
            fi
        fi
    done
fi

# Remove temporary files
print_banner Cleaning up
if [ "$opt_debug" != "yes" ]
then
    echo -e "\nRemoving temporary local directory ..."
    rm -rf $local_tmp_dir
fi

