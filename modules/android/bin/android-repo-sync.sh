#!/usr/bin/env bash

# android-repo-sync

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/path.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

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

arg_paths=

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
			-j*)
				opt_numjobs=$(echo $token | sed -e 's/^-j//')
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
				[[ -n $arg_paths ]] && arg_paths="${arg_paths} "
				arg_paths="${arg_paths}${token}"
				;;
		esac
	done

	# Apply defaults
	[[ -z $opt_numjobs ]] && opt_numjobs=$DEFAULT_NUMJOBS
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Paths ................................... $arg_paths

Dry run ................................. $opt_dryrun
Force ................................... $opt_force
Verbosity ............................... $opt_verbosity

Number of jobs .......................... $opt_numjobs

EOF
}

function print_python_version()
{
	local python_bin=$(which python)
	local python_version=$(python --version 2>&1 | sed -e 's/.* //g')
	echo "$python_bin ($python_version)"
}

function check_python_version()
{
	# "repo sync -j<LOTS>" hangs under Python 2.7.2 - see if we have another version to use
	print_banner "Checking Python version"
	echo -n "Python: "
	print_python_version
	local orig_path=$PATH
	local restore=1
	if [[ $(python --version 2>&1 | sed -e 's/.* //g') == 2.7.2 ]]; then
		PATH=$(path_remove $(dirname $(which python)) $PATH)
		if [[ -n $(which python 2>/dev/null) ]]; then
			if [[ $(python --version 2>&1 | sed -e 's/.* //g') != 2.7.2 ]]; then
				restore=0
			fi
		fi
	fi
	if [[ $restore == 1 ]]; then
		PATH=$orig_path
	else
		echo -n "Replaced python with: "
		print_python_version
	fi
	export PATH
}

function do_sync()
{
	check_python_version

	print_banner "Syncing ..."

	[[ -z $ANDROID_SRC ]] && error ANDROID_SRC is not set

	execute cd $ANDROID_SRC

	execute repo sync -j $opt_numjobs $arg_paths

	if [[ $opt_dryrun != yes ]]; then
		echo -e "\nWaiting for repo jobs to finish ..."
		sleep 5
	fi

	timestamp=$(date '+%y%m%d-%H%M%S')
	manifest_file=$ANDROID_SRC/.repo/manifest_${timestamp}.xml

	echo -e "\nSaving manifest to $manifest_file ..."

	execute repo manifest -r -o $manifest_file
}

function do_kill()
{
	print_banner "Killing repo ..."
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

[[ $opt_kill == yes ]] && do_kill

do_sync

print_banner Done

