#!/bin/bash

# symbian-patch-version

# Script for patching Symbian ARM DLL versions

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='target version'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no
option_patch=yes
option_force=no

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
	echo -e "\nError: $*"
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
	if [ "$option_verbosity" != silent ]
	then
		echo "$cmd"
	fi
	if [ "$option_dryrun" != yes ]
	then
		$cmd
		r=$?
		if [ "$r" != 0 ]
		then
			error $r Execution of '$cmd' failed: exit code $r
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
symbian-patch-version script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    target                  Build target (e.g. armv5_urel)
    version                 DLL version

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit
	--no-patch              Find DLLs and list them, but do not patch
    -f, --force             Patch even when requested version is lower than current

EOF
}

function print_version()
{
	cat << EOF
symbian-patch-version script version $SCRIPT_VERSION
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

			-no-patch | --no-patch)
				option_patch=no
				;;
			-f | -force | --force)
				option_force=yes
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
Patch ................................... $option_patch
Force patching to lower version ......... $option_force

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
# The guts
#------------------------------------------------------------------------------

dlls=
function find_dlls()
{
	test "$option_verbosity" != silent && echo -e "\nFinding DLLs ..."
	local sbs='sbs'
	if [ $METASYSTEM_OS == 'windows' ]
	then
		sbs="winwrapper $SBS_HOME/bin/sbs.bat"
	fi
	local args="-c $arg_target --what 2>&1"
	local cmd="$sbs $args"
	local print_cmd="sbs $args"
	test "$option_verbosity" != silent && echo -e "$print_cmd"
	output=`$cmd`
	r=$?
	if [ "$r" == 0 ]
	then
		# Filter output
		# Note that 'sbs --what' lists WINSCW DLLs if they are exported rather than
		# being built (e.g. Qt's sqlite3.dll) - so we filter those out here
		dll_list=$(echo "$output" | grep -i '\.dll$' | grep -iv winscw | grep -iv warning)
		test "$option_verbosity" != silent && echo -e "\nDLLs:"
		for dll in $dll_list
		do
			native_dll=$(metasystem_nativepath $dll)
			dlls="$dlls $native_dll"
			test "$option_verbosity" != silent && echo "    $native_dll"
		done
	else
		error $r Execution of \"$print_cmd\" failed: exit code $r
	fi
}

function current_version()
{
	local dll=$1
	elftran -dump h $dll | grep 'Module Version' | awk ' { print $3 } '
}

function patch_dll()
{
	local dll=$1
	echo "Patching to version $arg_version ..."
	local dll_orig=$1.orig
	local option_verbosity_orig=$option_verbosity
	option_verbosity=silent
	execute rm -f $dll_orig
	execute cp $dll $dll_orig
	execute elftran -version $arg_version $dll
	option_verbosity=$option_verbosity_orig
}

function process_dlls()
{
	test "$option_verbosity" != silent && echo -e "\nProcessing DLLs ..."
	for dll in $dlls
	do
		if [ -e $dll ]
		then
			echo
			echo "Processing $dll"
			local current=$(current_version $dll)
			echo "Current version $current"
			# Check whether current version is higher than requested version
			# We have to use awk to do this, since BASH doesn't understand
			# floating-point numbers
			local skip=
			local current_lower=`echo "$current $arg_version" | awk '{if ($1 <= $2) print "yes"}'`
			if [ -z "$current_lower" ]
			then
				echo "Requested version $arg_version is lower than current version"
				if [ "$option_force" != 'yes' ]
				then
					skip=yes
					echo " - skipping"
				else
					echo ".  --force specified, so patching anyway"
				fi
			fi
			test -z "$skip" -a "$option_patch" == yes && patch_dll $dll
		else
			echo "$dll not found - skipping"
		fi
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

find_dlls
process_dlls

