#!/usr/bin/env bash

# qt-makesis

# Qt installation script

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_QT_LIB/functions.sh
source $METASYSTEM_CORE_LIB_BASH/misc.sh

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
option_qmake=no
option_rnd=yes
option_cert=yes
option_install=no
option_upgrade=no

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
	test "$option_verbosity" != silent && echo -e "$cmd"
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
qt-makesis script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --qmake                 Run qmake
    --no-qmake              Do not run qmake
    --rnd                   Use R&D certificate
    --no-rnd                Don't use R&D certificate
    --no-cert               Don't use any certificate
    --install               Install SIS file to device
    --upgrade               Add TYPE=SA,NR,RU to .pkg file header

EOF
}

function print_version()
{
	cat << EOF
qt-makesis script version $SCRIPT_VERSION
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

            -qmake | --qmake)
				option_qmake=yes
				;;
			-no-qmake | --no-qmake)
				option_qmake=no
				;;

			-rnd | --rnd)
				option_rnd=yes
				;;
			-no-rnd | --no-rnd)
				option_rnd=no
				;;

			-no-cert | --no-cert)
				option_cert=no
				;;

			-install | --install)
				option_install=yes
				;;

			--upgrade)
				option_upgrade=yes
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

	cat << EOF
Run qmake ............................... $option_qmake
Use certificate ......................... $option_cert
Sign with R&D certificate ............... $option_rnd
Use upgrade flags ....................... $option_upgrade
Install to device ....................... $option_install
EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# In its present version, this script can only be run on Windows
# This is due in part to its usage of the metasystem_drivepath function
metasystem_assert_os windows $0

parse_command_line $*

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

test "$option_dryrun" == "no" && echo "Running in $PWD"

if [ "$option_qmake" == "yes" ]
then
	print_banner Running qmake
	execute winwrapper qmake
fi

qt_version=`winwrapper qmake -v | grep 'Qt version' | awk '{print $4}' | sed -e 's/\./ /g'`
qt_major=`echo $qt_version | awk '{print $1}'`
qt_minor=`echo $qt_version | awk '{print $2}'`
if [ ! -z "$qt_major" -a ! -z "$qt_minor" ]
then
	if [ "$qt_major" -lt 5 -a "$qt_minor" -lt 7 ] # Qt < 4.7.0
	then
		print_banner Patching capabilities
		execute qt-patch-caps.sh --silent

		if [ "$rnd" == "1" ]
		then
			print_banner Removing SQLite from .pkg file
			execute qt-remove-sqlite.sh --silent
		fi
	fi
fi

if [ "$option_upgrade" == "yes" ]
then
	echo "Adding upgrade flags to PKG file"
	for pkg in `'ls' *_template.pkg`
	do
		echo "$pkg"
		execute symbian-patch-pkg.sh $pkg --upgrade --quiet
	done
fi

print_banner Building SIS file
if [ "$option_cert" == "no" ]
then
	echo "Setting QT_SIS_CERTIFICATE and QT_SIS_KEY to empty strings"
	export QT_SIS_CERTIFICATE=
	export QT_SIS_KEY=
fi
execute make sis

project=`'ls' *_template.pkg | sed -e 's/_template\.pkg//'`
sis=$project.sis
if [ "$option_cert" == "yes" -a "$option_rnd" == "yes" ]
then
	print_banner Signing SIS file with RnD02 certificate
	execute qt-signsis.sh rnd_02 --silent
	signed_sis=${project}_signed.sis
	test -e ${signed_sis} && rm -f $sis && mv -v $signed_sis $sis
fi

if [ "$option_install" == "yes" ]
then
	print_banner Installing on device
	execute symbian-install.sh -q $sis
fi

