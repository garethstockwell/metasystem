#!/bin/bash

# qt-patch-caps

# Script for patching capabilities of Qt binaries

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

. `dirname "$0"`/qt-functions.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
# First argument is an error code
function error()
{
	code=$1
	shift
	echo "Error $code: $*"
	if [ "$option_dryrun" != yes ]
	then
		exit $code
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
	test "$option_verbosity" != silent && echo -e "\n$cmd"
	if [ "$option_dryrun" != yes ]
	then
		$cmd
		r=$?
		if [ "$r" != 0 ]
		then
			error $r Execution of '$cmd' failed
		fi
	fi
}

function print_rule()
{
	test "$option_verbosity" != silent && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [ "$option_verbosity" != silent ]
	then
		echo
		print_rule
		echo $*
		print_rule
		echo
	fi
}

function print_usage()
{
	cat << EOF
qt-patch-caps script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
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
qt-patch-caps script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	for token
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-h | -help | --help | -usage | --usage)
				option_help=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				option_verbosity=silent
				;;
			-v | -verbose | --verbose)
				option_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				option_dryrun=yes
				;;
			-V | -version | --version)
				option_version=yes
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
				warn Unrecognized option '$token' ignored
				;;

			# Normal arguments
			*)
				local arg_used=
				for arg in $ARGUMENTS
				do
					if [ -z `eval "echo \\$arg_$arg"` ]
					then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				test -z "$arg_used" && warn Additional argument '$token' ignored
				;;
		esac
	done

	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $ARGUMENTS
	do
		if [ -z `eval "echo \\$arg_$arg"` ]
		then
			args_supplied=
			break
		fi
	done
	test -z "$args_supplied" && usage_error 'Insufficient arguments provided'
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF
Verbosity ............................... $option_verbosity
Dry run ................................. $option_dryrun
EOF
	for arg in $ARGUMENTS
	do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line $*

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution

script=$QT_BUILD_DIR/bin/patch_capabilities.pl
test ! -f "$script" && error 1 "patch-capabilities.pl not found in QT_BUILD_DIR '$QT_BUILD_DIR'"

target=
if [ -e .make.cache ]
then
	target=`cat .make.cache | grep QT_SIS_TARGET | awk '{ print $3 }'`
	echo "target: $target"
else
	error 1 "No .make.cache file found"
fi

for pkg in `'ls' *_template.pkg`
do
	echo "pkg file: $pkg"
	execute perl $(nativepath $script) $pkg $target
done

