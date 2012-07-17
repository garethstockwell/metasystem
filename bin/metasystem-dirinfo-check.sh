#!/bin/bash

# metasystem-dirinfo-check
# Script for checking whether smartcd and .metasystem-dirinfo files are in sync

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='dir'

SMARTCD_SCRIPT_DIR=~/.smartcd/scripts

# Command which should be executed in smartcd bash_enter
SMARTCD_ENTER_CMD='metasystem_parse_dirinfo __PATH__'


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_depth=

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
metasystem-dirinfo-check script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    dir                     Directory

Options:
    -d, --depth             Maximum search depth
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
metasystem-dirinfo-check script version $SCRIPT_VERSION
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

			-d | -depth | --depth)
				prev=opt_depth
				;;
			-d=* | -depth=* | --depth=*)
				opt_depth=$optarg
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

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Depth ................................... $depth

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

function process_dirinfo()
{
	print_banner .metasystem-dirinfo ...
	echo -e "\nSearching ..."
	local list=$(find $arg_dir $find_depth -iname .metasystem-dirinfo)
	echo -e "Checking ...\n"
	for file in $list; do
		local dir=$(dirname $file)
		echo $dir
		local bash_enter=$SMARTCD_SCRIPT_DIR/$dir/bash_enter
		local bash_leave=$SMARTCD_SCRIPT_DIR/$dir/bash_leave
		local bash_enter_ok=
		[[ ! -e $bash_enter ]] && echo "    bash_enter not found"
		[[ ! -e $bash_leave ]] && echo "    bash_leave not found"
		if [[ ! -e $bash_enter && ! -e $bash_leave ]]; then
			echo "    Installing smartcd ..."
			[[ "$opt_dryrun" != "yes" ]] &&\
				builtin cd $dir &&\
				smartcd template install metasystem
		fi
		[[ -e $bash_enter ]] &&\
			bash_enter_ok=$(cat $bash_enter | grep "$SMARTCD_ENTER_CMD")
		if [[ -e $bash_enter && -z "$bash_enter_ok" ]]; then
			echo "    bash_enter does not contain metasystem_parse_dirinfo"
			echo "    Appending metasystem_parse_dirinfo to bash_enter ..."
			[[ "$opt_dryrun" != "yes" ]] &&\
				echo $SMARTCD_ENTER_CMD >> $bash_enter
		fi
		[[ -n $(cat $file | grep '^shell ') ]] &&\
			echo "    metasystem-dirinfo uses deprecated 'shell' command"
	done
}

function process_smartcd()
{
	print_banner smartcd
	echo -e "\nSearching ..."
	local enter_list=$(find $SMARTCD_SCRIPT_DIR $find_depth -iname bash_enter)
	local leave_list=$(find $SMARTCD_SCRIPT_DIR $find_depth -iname bash_leave)
	local list=
	for file in $enter_list $leave_list; do
		list=$list$(dirname $file)'\n'
	done
	list=$(echo -e $list | sort | uniq)
	echo -e "Checking ...\n"
	for script_dir in $list; do
		local dir=${script_dir:${#SMARTCD_SCRIPT_DIR}}
		echo $dir
		local bash_enter=$script_dir/bash_enter
		local bash_enter_ok=
		[[ -e $bash_enter ]] &&\
			bash_enter_ok=$(cat $bash_enter | grep "$SMARTCD_ENTER_CMD")
		if [[ -e $bash_enter && -z "$bash_enter_ok" ]]; then
			echo "    bash_enter does not contain metasystem_parse_dirinfo"
			echo "    Appending metasystem_parse_dirinfo to bash_enter ..."
			[[ "$opt_dryrun" != "yes" ]] &&\
				echo $SMARTCD_ENTER_CMD >> $bash_enter
		fi
		if [[ -d $dir ]]; then
			local dirinfo=$dir/.metasystem-dirinfo
			if [[ ! -e $dirinfo ]]; then
				echo "    .metasystem-dirinfo not found"
			fi
		else
			echo "    $dir not found - consider running 'smartcd purge'"
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

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

test -n "$opt_depth" && find_depth="-maxdepth $opt_depth"

SMARTCD_CONFIG=~/.smartcd_config
[[ -e $SMARTCD_CONFIG ]] || error "$SMARTCD_CONFIG not found"
source $SMARTCD_CONFIG

process_dirinfo
[[ -d $SMARTCD_SCRIPT_DIR ]] && process_smartcd

