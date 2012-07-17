#!/bin/bash

# qt-configure.sh

# Script for configuring Qt

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

. `dirname "$0"`/qt-functions.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='platform'

DEFAULT_BUILD_TARGETS_OTHER=
DEFAULT_BUILD_TARGETS_WINDOWS=debug-and-release
DEFAULT_STATIC=no
DEFAULT_DEVELOPER_BUILD=no
DEFAULT_INCREDIBUILD=no
DEFAULT_NAMESPACE=no
DEFAULT_QT4_INFIX=
DEFAULT_QT5_INFIX=
DEFAULT_DEMOS=no
DEFAULT_EXAMPLES=no
DEFAULT_TESTS=no
DEFAULT_TOOLS=no
DEFAULT_OPENVG=yes
DEFAULT_DECLARATIVE=yes
DEFAULT_PHONON=no
DEFAULT_QT4_SCRIPT=yes
DEFAULT_QT5_SCRIPT=no
DEFAULT_WEBKIT=no
DEFAULT_XMLPATTERNS=no

VALID_PLATFORMS='windows linux symbian harmattan'

VALID_OPENGL='no desktop es1 es2'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no

option_platform=
option_xplatform=

# Options below are set from DEFAULT_XXX values

option_build_targets=
option_static=
option_developer_build=
option_incredibuild=
option_namespace=
option_prefix=
option_rpath=
option_infix=

option_demos=
option_examples=
option_tests=
option_tools=

option_opengl=
option_openvg=
option_declarative=
option_phonon=
option_script=
option_webkit=
option_xmlpatterns=

# Extra stuff which gets passed directly to Qt's configure
option_extra=

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

function list_contains()
{
    local element=$1
    shift
    local list="$*"
    local result=
    for x in $list
    do
        test "$x" == "$element" && result=1
    done
    echo $result
}

function list_pipe_separated()
{
    local list="$*"
    echo $list | sed -e 's/ /|/g'
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

function append_to()
{
	local var=$1
	local token=$2
	local value=`eval echo \\$$var`
	test -n "$value" && value="$value "
	value="$value$token"
	eval "$var=\$value"
}

function print_usage()
{
	# [CHANGE] Modify descriptions of arguments and options
	cat << EOF
qt-configure.sh script

Usage: $0 <platform> [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    platform                ${VALID_PLATFORMS// /|}

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --debug                 Build only debug
    --release               Build only release

    --static                Static build
    -d | --developer-build  Developer build
    -p | --prefix           Prefix
    --rpath PATH            Use -rpath
    --no-rpath              Do not use-rpath
    -i | --infix INFIX      Use libinfix
    --no-infix              Do not infix
    --ib                    Incredibuild

    --namespace NAMESPACE   Use namespace

    --examples
    --no-examples

    --demos
    --no-demos

    --tests
    --no-tests

    --tools
    --no-tools

*   --openvg                Enable OpenVG
    --no-openvg             Disable OpenVG

    --opengl TYPE           Enable OpenGL ($(list_pipe_separated $VALID_OPENGL))
    --no-opengl             Disable OpenGL(ES)

*   --declarative           Enable QtDeclarative
    --no-declarative        Disable QtDeclarative

    --webkit                Enable QtWebKit
*   --no-webkit             Disable QtWebKit

    --xmlpatterns           Enable QtXmlPatterns
*   --no-xmlpatterns        Disable QtXmlPatterns

    --extra EXTRA           Extra args to pass directly to Qt configure

EOF
}

function print_version()
{
	cat << EOF
qt-configure.sh script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	for token
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"
		then
			append_to $prev $token
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
			-j)
				prev=option_makenumjobs
				;;
			-j=*)
				option_makenumjobs=$optarg
				;;

			-debug | --debug)
				option_build_targets=debug
				;;
			-release | --release)
				option_build_targets=release
				;;

			-static | --static)
				option_static=yes
				;;
			-ib | --ib)
				option_incredibuild=yes
				;;

			-i | -infix | --infix)
				prev=option_infix
				;;
			-i=* | -infix=* | --infix=*)
				option_infix=$optarg
				;;

			-no-infix | --no-infix)
				option_infix=none
				;;

			-p | -prefix | --prefix)
				prev=option_prefix
				;;
			-p=* | -prefix=* | --prefix=*)
				option_prefix=$optarg
				;;

			-rpath | --rpath)
				prev=option_rpath
				;;
			-rpath=* | --rpath=*)
				option_rpath=$optarg
				;;
			-no-rpath | --no-rpath)
				option_rpath=no
				;;

			-demos | --demos)
				option_demos=yes
				;;
			-no-demos | --no-demos)
				option_demos=no
				;;
			-examples | --examples)
				option_examples=yes
				;;
			-no-examples | --no-examples)
				option_examples=no
				;;
			-tests | --tests)
				option_tests=yes
				;;
			-no-tests | --no-tests)
				option_tests=no
				;;
			-tools | --tools)
				option_tools=yes
				;;
			-no-tools | --no-tools)
				option_tools=no
				;;

			-openvg | --openvg)
				option_openvg=yes
				;;
			-no-openvg | --no-openvg)
				option_openvg=no
				;;

			-opengl | --opengl)
				prev=option_opengl
				;;
			-opengl=* | --opengl=*)
				option_opengl=$optarg
				;;
			-no-opengl | --no-opengl)
				option_opengl=no
				;;

			-declarative | --declarative)
				option_declarative=yes
				;;
			-no-declarative | --no-declarative)
				option_declarative=no
				;;
			-webkit | --webkit)
				option_webkit=yes
				;;
			-no-webkit | --no-webkit)
				option_webkit=no
				;;
			-xmlpatterns | --xmlpatterns)
				option_xmlpatterns=yes
				;;
			-no-xmlpatterns | --no-xmlpatterns)
				option_xmlpatterns=no
				;;

			-d | -developer-build | --developer-build)
				option_developer_build=yes
				;;

			-namespace | --namespace)
				prev=option_namespace
				;;
			-namespace=* | --namespace=*)
				option_namespace=$optarg
				;;

			-extra | --extra)
				prev=option_extra
				;;
			-extra=* | --extra=*)
				append_to option_extra $optarg
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
				test -z "$arg_used" && warn Additional argument "$token" ignored
				;;
		esac
	done

	# Validate
    test -z $(list_contains $arg_platform $VALID_PLATFORMS) &&\
        usage_error "Invalid platform"

	if [ -z "$option_build_targets" ]
	then
		option_build_targets=$DEFAULT_BUILD_TARGETS_OTHER
		test "$arg_platform" == "windows" && option_build_targets=$DEFAULT_BUILD_TARGETS_OTHER
	fi

	test -z "$option_static" && option_static=$DEFAULT_STATIC
	test -z "$option_developer_build" && option_developer_build=$DEFAULT_DEVELOPER_BUILD
	test -z "$option_incredibuild" && option_incredibuild=$DEFAULT_INCREDIBUILD

	if [ -z "$option_infix" ]
	then
		test "$qt_version" == '4' && option_infix=$DEFAULT_QT4_INFIX
		test "$qt_version" == '5' && option_infix=$DEFAULT_QT5_INFIX
	fi

	if [ "$option_infix" == "none" ]
	then
		option_infix=
	fi

	test -z "$option_demos" && option_demos=$DEFAULT_DEMOS
	test -z "$option_examples" && option_examples=$DEFAULT_EXAMPLES
	test -z "$option_tests" && option_tests=$DEFAULT_TESTS
	test -z "$option_tools" && option_tools=$DEFAULT_TOOLS
	test -z "$option_openvg" && option_openvg=$DEFAULT_OPENVG
	test -z "$option_declarative" && option_declarative=$DEFAULT_DECLARATIVE
	test -z "$option_phonon" && option_phonon=$DEFAULT_PHONON

	case $arg_platform in
		linux)
			option_platform=
			option_xplatform=
			;;
		mac)
			option_platform=
			option_xplatform=
			;;
		symbian)
			option_platform=win32-g++
			option_xplatform=symbian-sbsv2
			test -z "$option_opengl" && option_opengl=es2
			;;
		windows)
			option_platform=win32-msvc2010
			option_xplatform=
			;;
		harmattan)
			option_platform=
			# Use custom mkspec which this script injects into the Qt source tree
			option_xplatform=linux-harmattan
			test -z "$option_opengl" && option_opengl=es2
			;;
	esac

	if [ -z "$option_script" ]
	then
		test "$qt_version" == '4' && option_script=$DEFAULT_QT4_SCRIPT
		test "$qt_version" == '5' && option_script=$DEFAULT_QT5_SCRIPT
	fi

	test -z "$option_webkit" && option_webkit=$DEFAULT_WEBKIT
	test -z "$option_xmlpatterns" && option_xmlpatterns=$DEFAULT_XMLPATTERNS

	test "$arg_platform" != "windows" && option_incredibuild=no
	test "$arg_platform" != "symbian" && option_openvg=no
	test "$option_declarative" == "yes" -a "$qt_version" == "4" && option_script=yes
	test "$option_declarative" == "yes" -a "$qt_version" == "5" && option_xmlpatterns=yes

	test -z "$option_makenumjobs" && option_makenumjobs=1

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

	if [ -n "$option_opengl" ]
	then
		test -z $(list_contains $option_opengl $VALID_OPENGL) &&\
			usage_error "Invalid value for -opengl"
	fi
}

function print_summary()
{
	print_banner 'Qt configuration summary'
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

local host_platform=$option_platform
test -z "$host_platform" && host_platform=$arg_platform

	cat << EOF
platform ................................ $host_platform
xplatform ............................... $option_xplatform

Qt version .............................. $qt_version

build target(s) ......................... $option_build_targets
static build ............................ $option_static
developer build ......................... $option_developer_build
IncrediBuild ............................ $option_incredibuild
namespace ............................... $option_namespace
number of make jobs ..................... $option_makenumjobs
prefix .................................. $option_prefix
rpath ................................... $option_rpath
infix ................................... $option_infix

demos ................................... $option_demos
examples ................................ $option_examples
tests ................................... $option_tests
tools ................................... $option_tools

OpenGL .................................. $option_opengl
OpenVG .................................. $option_openvg
QtDeclarative ........................... $option_declarative
QtScript ................................ $option_script
QtWebKit ................................ $option_webkit
QtXmlPatterns............................ $option_xmlpatterns

Extra options ........................... $option_extra
EOF
}

function detect_qt_version()
{
	qt_version=4
	test -d $QT_SOURCE_DIR/qtbase && qt_version=5
	echo "Qt major version = $qt_version"
}

function detect_num_cpus()
{
	num_cpus=$NUMBER_OF_PROCESSORS
	if [ -z "$num_cpus" -a "$METASYSTEM_OS" == "linux" ]
	then
		num_cpus=`cat /proc/cpuinfo | grep processor | wc -l`
	fi
	echo "Number of CPUs = $num_cpus"
	option_makenumjobs=$num_cpus
}

function add_harmattan_mkspec()
{
	mkspec_name=linux-harmattan
	mkspec_root=$QT_SOURCE_DIR/mkspecs
	test "$qt_version" == "5" && mkspec_root=$QT_SOURCE_DIR/qtbase/mkspecs
	mkspec_dir=$mkspec_root/$mkspec_name
	rm -rf $mkspec_dir
	mkdir -p $mkspec_dir
	cat > $mkspec_dir/qmake.conf << EOF
# Generated by qt-configure.sh

CONFIG += linux-g++-maemo
CONFIG += maemo6
MEEGO_EDITION = harmattan
# Suppress warning about changed mangling of va_list in GCC 4.4
QMAKE_CXXFLAGS += -Wno-psabi
include(../linux-g++-maemo/qmake.conf)
EOF
	cat > $mkspec_dir/qplatformdefs.h << EOF
/* Generaed by qt-configure.sh */

#include "../linux-g++-maemo/qplatformdefs.h"
EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

print_banner Starting execution
echo

detect_qt_version
detect_num_cpus

parse_command_line $*

if [ ! -z "$option_infix" -a "$option_developer_build" == "no" ]
then
	echo "Adding --developer-build since infix has been specified"
	option_developer_build=yes
fi

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0

test "$option_verbosity" != silent && print_summary

check_pwd_in_qt_build_dir
check_qt_source_dir

command=$QT_SOURCE_DIR/configure
case $arg_platform in
	symbian | windows)
		test "$qt_version" == "4" && command=$command.exe
		test "$qt_version" == "5" && command="`which perl` $command"
		;;
esac

test -n "$option_platform" && command="$command -platform $option_platform"
test -n "$option_xplatform" && command="$command -xplatform $option_xplatform"
test -n "$option_build_targets" && command="$command -$option_build_targets"

# Prefix
if [ "$option_prefix" == 'auto' ]
then
	case $arg_platform in
		linux | mac)
			option_prefix="$QT_BUILD_DIR/../install"
			;;
		windows)
			option_prefix="$(nativepath $QT_BUILD_DIR/../install)"
			;;
	esac
fi
test -n "$option_prefix" && command="$command -prefix $option_prefix"

# PCH
case $arg_platform in
	linux | mac)
		command="$command -pch"
		;;
esac

# rpath
if [ ! -z "$option_rpath" ]
then
	case $option_rpath in
		no)
			command="$command -no-rpath"
			;;
		default)
			command="$command -rpath"
			;;
		*)
			command="$command -no-rpath -R $option_rpath"
			;;
	esac
fi

# Exclude GTK style when building Qt5 on Linux
# This is because on a number of systems (at least SUSE and Gentoo)
# `pkg-config —cflags gtk+-2.0` actually returns paths that include the system Qt4.x
# include directories.
if [ "$qt_version" == '5' ]
then
	if [ "$arg_platform" == "linux" ]
	then
		ubuntu=
		test -e /etc/issue -a ! -z "$(grep -i ubuntu /etc/issue)" && ubuntu=1
		test -z "$ubuntu" && command="$command -no-gtkstyle"
	fi
fi

if [ "$arg_platform" == "harmattan" ]
then
	test -z "$SYSROOT_DIR" && error "SYSROOT_DIR is not set"
	command="$command -force-pkg-config -no-pch -separate-debug-info"
	test "$qt_version" == "4" && command="$command -arch arm"
	command="$command -sysroot $SYSROOT_DIR"
	test "$option_dryrun" != "yes" && add_harmattan_mkspec
fi

test "$option_static" == "yes" && command="$command -static"
test "$option_developer_build" == "yes" && command="$command -developer-build"

# Make engine
case $arg_platform in
	windows)
		if [ "$option_incredibuild" == "yes" ]
		then
			command="$command -make ibjom.cmd"
		else
			command="$command -make jom"
		fi
		;;
esac

command="$command -opensource -confirm-license"

if [ "$qt_version" == '4' ]
then
	test "$option_demos" == "no" && command="$command -nomake demos"
fi

test "$option_examples" == "no" && command="$command -nomake examples"
test "$option_examples" == "yes" && command="$command -make examples"
test "$option_tests" == "no" && command="$command -nomake tests"
test "$option_tests" == "yes" && command="$command -make tests"
test "$option_tools" == "no" && command="$command -nomake tools"
test "$option_tools" == "yes" && command="$command -make tools"

if [ "$qt_version" == '4' ]
then
	if [ "$option_opengl" == "no" ]
	then
		command="$command -no-opengl"
	else
		command="$command -opengl $option_opengl"
	fi
	test "$option_openvg" == "yes" && command="$command -openvg"
	test "$option_declarative" == "no" && command="$command -no-declarative"
	test "$option_phonon" == "no" && command="$command -no-phonon"
	test "$option_script" == "no" && command="$command -no-script -no-scripttools"
	test "$option_webkit" == "no" && command="$command -no-webkit"
	test "$option_xmlpatterns" == "no" && command="$command -no-xmlpatterns"

	graphicssystem=
	test "$arg_platform" == "symbian" && test "$option_opengl" == "es2" && graphicssystem="opengl"
	test "$option_openvg" == "yes" && graphicssystem="openvg"
	test "$arg_platform" == "harmattan" && graphicssystem="runtime"
	test -n "$graphicssystem" && command="$command -graphicssystem $graphicssystem"
fi

test -n "$option_namespace" && command="$command -qtnamespace $option_namespace"
test -n "$option_infix" && command="$command -qtlibinfix _$option_infix"

test "$option_verbosity" == "silent" && command="$command -silent"
test "$option_verbosity" == "verbose" && command="$command -verbose"

test "$option_developer_build" == "yes" -a -z "$option_infix" && \
	echo -e "\nWarning: --developer-build was specified but --infix was not"

command="$command $option_extra"

echo
echo $command

export MAKEFLAGS=-j${option_makenumjobs}

if [ "$option_dryrun" == "no" ]
then
	if [ "$METASYSTEM_PLATFORM" == "mingw" ]
	then
		# Ensure PATH used by configure.exe is in Windows format
		PATH=$(nativepathlist $PATH) $command
	else
		$command
	fi
fi

