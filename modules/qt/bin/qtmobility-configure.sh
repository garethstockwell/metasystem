#!/usr/bin/env bash

# qtmobility-configure

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_QT_LIB/functions.sh
source $METASYSTEM_CORE_LIB_BASH/path.sh

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
option_prefix=

option_platform=
option_build_target=release
option_build_examples=no
option_build_demos=no
option_build_tests=no
option_build_docs=no
option_build_tools=yes
option_modules=multimedia

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
	fi
}

function print_usage()
{
	cat << EOF
qtmobility-configure script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --prefix PREFIX         Set installation prefix

    --debug                 Build with debugging symbols
	--debug-and-release     Build both

    --examples              Build examples
*   --no-examples           Do not build examples

    --demos                 Build demos
*   --no-demos              Do not build demos

    --tests                 Build tests
*   --no-tests              Do not build tests

    --docs                  Build docs
*   --no-docs               Do not build docs

*   --tools                 Build tools
    --no-tools              Do not build tools

    --harmattan             Build for harmattan

EOF
}

function print_version()
{
	cat << EOF
qtmobility-configure script version $SCRIPT_VERSION
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
			# Modules
			bearer|contacts|location|messaging|multimedia|publishsubscribe|serviceframework|systeminfo|sensors|gallery|versit|feedback|organizer)
				if [ -z "$in_modules" ]
				then
					warn "Additional argument '$token' ignored"
				else
					option_modules="$option_modules $token"
				fi
				;;

			# Options
			-h | -help | --help | -usage | --usage)
				option_help=yes
				in_modules=
				;;
			-q | -quiet | --quiet | -silent | --silent)
				option_verbosity=silent
				in_modules=
				;;
			-v | -verbose | --verbose)
				option_verbosity=verbose
				in_modules=
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				option_dryrun=yes
				in_modules=
				;;
			-V | -version | --version)
				option_version=yes
				in_modules=
				;;

			-prefix | --prefix)
				prev=option_prefix
				;;
			-prefix=* | --prefix=*)
				option_prefix=$optarg
				;;

			-debug | --debug)
				option_build_target=debug
				;;

			-debug-and-release | --debug-and-release)
				option_build_target='debug -release'
				;;

			-examples | --examples)
				option_build_examples=yes
				in_modules=
				;;
			-no-examples | --no-examples)
				option_build_examples=no
				in_modules=
				;;
			-demos | --demos)
				option_build_demos=yes
				in_modules=
				;;
			-no-demos | --no-demos)
				option_build_demos=no
				in_modules=
				;;
			-tests | --tests)
				option_build_tests=yes
				in_modules=
				;;
			-no-tests | --no-tests)
				option_build_tests=no
				in_modules=
				;;
			-docs | --docs)
				option_build_docs=yes
				in_modules=
				;;
			-no-docs | --no-docs)
				option_build_docs=no
				in_modules=
				;;
			-tools | --tools)
				option_build_tools=yes
				in_modules=
				;;
			-no-tools | --no-tools)
				option_build_tools=no
				in_modules=
				;;

			-modules=* | --modules=*)
				option_modules="$optarg"
				in_modules=1
				;;
			-modules | --modules)
				prev=option_modules
				in_modules=1
				;;

			-harmattan | --harmattan)
				option_platform=harmattan
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
				warn Unrecognized option "$token" ignored
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
				test -z "$arg_used" && warn "Additional argument '$token' ignored"
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

	cat << EOF

Build target ............................ $option_build_target
Modules ................................. $option_modules
Prefix .................................. $option_prefix

Build examples .......................... $option_build_examples
Build demos... .......................... $option_build_demos
Build tests ............................. $option_build_tests
Build docs .............................. $option_build_docs
Build tools ............................. $option_build_tools
EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_qtmobility_source_dir
check_pwd_in_qtmobility_build_dir

parse_command_line $*

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution

if [ "$METASYSTEM_OS" == "windows" ]
then
	command="winwrapper $METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR/configure.bat"
else
	command="$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR/configure"
fi

command="$command -$option_build_target"

test "$option_build_examples" == "yes" && command="$command -examples"
test "$option_build_demos" == "yes" && command="$command -demos"
test "$option_build_tests" == "yes" && command="$command -tests"
test "$option_build_docs" == "no" && command="$command -no-docs"
test "$option_build_tools" == "no" && command="$command -no-tools"
test -n "$option_modules" && test "$option_modules" != "all" && command="$command -modules $option_modules"

if [ ! -z "$option_prefix" ]
then
	build_dir=`pwd`
	if [ -d "$option_prefix" ]
	then
		cd $option_prefix
		option_prefix=$(metasystem_nativepath `pwd`)
		cd $build_dir
	fi
	command="$command -prefix $option_prefix"
fi

test "$option_platform" == "harmattan" && command="$command -maemo6"

execute $command

