#!/bin/bash

# qt-signsis

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

. `dirname "$0"`/qt-functions.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='cert'

CERT_DIR=~/work/sync/unison/live/projects/qt/certs

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no
option_pkg=

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
	fi
}

function print_usage()
{
	# [CHANGE] Modify descriptions of arguments and options
	cat << EOF
qt-signsis script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    cert                    Certificate name

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

	--pkg=PKG               Specify .pkg file name

EOF
}

function print_version()
{
	cat << EOF
qt-signsis script version $SCRIPT_VERSION
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

			-pkg | --pkg)
				prev=option_pkg
				;;
			-pkg=* | --pkg=*)
				option_pkg=$optarg
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

	cat << EOF
Package file ............................ $option_pkg
EOF
}

function sign_sis {
    sis_input=$1
    cert_name=$2

    sis_output=`echo $sis_input | sed -e 's/\.sis/_signed.sis/'`

    cert=
    key=
    case $arg_cert in
		rnd) cert=rd.cer; key=rd-key.pem ;;
		*) error 1 "invalid cert '$cert_name'" ;;
    esac

	test ! -e "$sis_input" && error 1 "SIS file '$sis_input' not found"
    echo "Signing $sis_input -> $sis_output with cert $arg_cert ..."

    execute rm -f $sis_output
    execute winwrapper signsis $sis_input $sis_output \
		$(nativepath $CERT_DIR/$arg_cert/$cert) \
		$(nativepath $CERT_DIR/$arg_cert/$key)
	echo
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line $*

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution
echo

if [ -z "$option_pkg" ]
then
	for pkg in `'ls' *_template.pkg`
	do
	    sis_input=`echo $pkg | sed -e 's/_template.pkg/.sis/'`
		sign_sis $sis_input $cert_name
	done
else
	sis_input=`echo $pkg | sed -e 's/.pkg/.sis/'`
	sign_sis $sis_input $cert_name
fi

