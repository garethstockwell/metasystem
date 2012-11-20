#!/bin/bash

# android-repo-sync

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

DEFAULT_NUMJOBS=8


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_force=no
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_kill=no

opt_numjobs=

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
	[[ "$opt_verbosity" != silent ]] && echo "$cmd"
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
android-repo-sync script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -f, --force             Remove existing files
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    -j, --jobs N            Number of jobs (default $DEFAULT_NUMJOBS)

EOF
}

function print_version()
{
	cat << EOF
android-repo-sync script version $SCRIPT_VERSION
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
			-f | -force | --force)
				opt_force=yes
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

			-j | -jobs | --jobs)
				prev=opt_numjobs
				;;
			-j=* | -jobs=* | --jobs=*)
				opt_numjobs=$optarg
				;;

            -k | -kill | --kill)
				opt_kill=yes
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
	[[ -z $opt_numjobs ]] && opt_numjobs=$DEFAULT_NUMJOBS
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Dry run ................................. $opt_dryrun
Force ................................... $opt_force
Verbosity ............................... $opt_verbosity

Number of jobs .......................... $opt_numjobs

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

function do_sync()
{
	echo

	[[ -z $ANDROID_SRC ]] && error ANDROID_SRC is not set

	execute cd $ANDROID_SRC

	execute repo sync -j $opt_numjobs

	echo -e "\nWaiting for repo jobs to finish ..."
	sleep 5

	timestamp=$(date '+%y%m%d-%H%M%S')
	manifest_file=$ANDROID_SRC/.repo/manifest_${timestamp}.xml

	echo -e "\nSaving manifest to $manifest_file ..."

	execute repo manifest -r -o $manifest_file
}

function do_kill()
{
	local pid_list=$(ps ax -u $(whoami) | grep '[r]epo' | grep -v $0 | awk '{ print $1 }')
	for pid in $pid_list; do
		local info=$(ps -o pid= -o cmd= $pid)
		if [[ -n $info ]]; then
			echo -e "\n$info"
			execute kill -9 $pid
		fi
	done
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

[[ $opt_kill == yes ]] && do_kill

do_sync

print_banner Done

