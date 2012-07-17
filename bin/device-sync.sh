#!/bin/bash

# device-sync

# This script is a wrapper around rsync, which is used to transfer files
# to/from remote devices.

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='local_dir remote_dir'

# Pick up environment variables, if set
DEFAULT_DEVICE_USER=$DEVICE_USER
DEFAULT_DEVICE_PASSWORD=$DEVICE_PASSWORD
DEFAULT_DEVICE_HOST=$DEVICE_HOST
DEFAULT_DEVICE_PORT=$DEVICE_PORT
DEFAULT_DEVICE_SHELL=$DEVICE_SHELL
DEFAULT_DEVICE_SCRIPT_DIR=/tmp


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_debug=
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no

opt_device_user=
opt_device_password=
opt_device_host=
opt_device_port=
opt_device_shell=
opt_device_rm=
opt_device_script_dir=
opt_direction=both

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
	[[ "$opt_verbosity" != silent ]] && echo -e "\n$cmd"
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
device-sync script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    local                   Local path
    remote                  Remote path

Options:
    -d, --debug             Print debugging information
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --user USER             Device user       (default: $DEFAULT_DEVICE_USER)
    --password PASSWORD     Device password   (default: ********)
    --host HOST             Device hostname   (default: $DEFAULT_DEVICE_HOST)
    --port PORT             Device port       (default: $DEFAULT_DEVICE_PORT)
    --shell SHELL           Device shell      (default: $DEFAULT_DEVICE_SHELL)
    --script-dir DIR        Device script dir (default: $DEFAULT_DEVICE_SCRIPT_DIR)

    --pull                  Only transfer remote -> local
    --push                  Only transfer local -> remote
    --both                  Bidirectional sync

EOF
}

function print_version()
{
	cat << EOF
device-sync script version $SCRIPT_VERSION
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

			-user | --user)
				prev=opt_device_user
				;;
			-user=* | --user=*)
				opt_device_user=$optarg
				;;

			-password | --password)
				prev=opt_device_password
				;;
			-password=* | --password=*)
				opt_device_password=$optarg
				;;

			-host | --host)
				prev=opt_device_host
				;;
			-host=* | --host=*)
				opt_device_host=$optarg
				;;

			-port | --port)
				prev=opt_device_port
				;;
			-port=* | --port=*)
				opt_device_port=$optarg
				;;

			-shell | --shell)
				prev=opt_device_shell
				;;
			-shell=* | --shell=*)
				opt_device_shell=$optarg
				;;

			-script-dir | --script-dir)
				prev=opt_device_script_dir
				;;
			-script-dir=* | --script-dir=*)
				opt_device_script_dir=$optarg
				;;


			-pull | --pull)
				opt_direction=pull
				;;
			-push | --push)
				opt_direction=push
				;;
			-both | --both)
				opt_direction=both
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

	# Apply defaults
	[[ -z $opt_device_user ]] && opt_device_user=$DEFAULT_DEVICE_USER
	[[ -z $opt_device_password ]] && opt_device_password=$DEFAULT_DEVICE_USER
	[[ -z $opt_device_host ]] && opt_device_host=$DEFAULT_DEVICE_USER
	[[ -z $opt_device_port ]] && opt_device_port=$DEFAULT_DEVICE_USER
	[[ -z $opt_device_shell ]] && opt_device_port=$DEFAULT_DEVICE_SHELL
	[[ -z $opt_device_script_dir ]] && opt_device_script_dir=$DEFAULT_DEVICE_SCRIPT_DIR

	# Check requirements
	[[ -z $opt_device_host ]] && error "No device host specified"
	[[ -z $opt_device_shell ]] && error "No device shell specified"
	[[ -z $opt_direction ]] && error "No direction specified"

	# It's a good bet that rm lives alongside the shell binary...
	opt_device_rm=$(dirname $opt_device_shell)/rm
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Device user ............................. $opt_device_user
Device password ......................... ********
Device host ............................. $opt_device_host
Device port ............................. $opt_device_port
Device shell ............................ $opt_device_shell
Device script dir ....................... $opt_device_script_dir

Direction ............................... $opt_direction

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

function ensure_dirs_exist()
{
	print_banner Ensuring directories exist
	if [[ $opt_dryrun != yes ]]; then
		# Remote directory
		if [[ $opt_direction != pull ]]; then
			script=device-sync-create-target-dir-$$.sh
			[[ -n $opt_debug ]] && echo "script name: $script"
			rm -f /tmp/$script
			cat > /tmp/$script << EOF
dir=$arg_remote_dir
test ! -d \$dir && mkdir -p \$dir
EOF
			scp /tmp/$script $remote:$opt_device_script_dir/$script
			ssh $remote $opt_device_shell $opt_device_script_dir/$script
			ssh $remote $opt_device_rm -f $opt_device_script_dir/$script
		fi
		# Local directory
		if [[ $opt_direction != push ]]; then
			[[ ! -d $arg_local_dir ]] && execute mkdir -p $arg_local_dir
		fi
	fi
}

function do_push()
{
	print_banner Pushing
	execute cd $arg_local_dir
	execute rsync -azvvrl -e ssh . $remote:$arg_remote_dir
}

function do_pull()
{
	print_banner Pulling
	execute rsync -azvvrl -e ssh $remote:$arg_remote_dir $arg_local_dir
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

remote=$opt_device_host
[[ -n $opt_device_user ]] && remote="${opt_device_user}@${remote}"
ensure_dirs_exist
[[ $opt_direction != pull ]] && do_push
[[ $opt_direction != push ]] && do_pull

