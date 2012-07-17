#!/bin/bash

# android-flash

# Script for flashing Android devices

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
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_initial_state=system
opt_wipe=no

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
	[[ "$opt_verbosity" != silent ]] && echo -e "$cmd"
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
android-flash script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    source                  Source path
    dest                    Destination path

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -w, --wipe              Wipe user data
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    -b, --bootloader        Specify that initial device state is bootloader

EOF
}

function print_version()
{
	cat << EOF
android-flash script version $SCRIPT_VERSION
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
			-w | -wipe | --wipe)
				opt_wipe=yes
				;;
			-V | -version | --version)
				opt_version=yes
				;;

			-b | -bootloader | --bootloader)
				opt_initial_state=bootloader
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

TARGET_PRODUCT .......................... $TARGET_PRODUCT
OUT ..................................... $OUT

Initial device state .................... $opt_initial_state
Wipe user data .......................... $opt_wipe

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

function reboot_bootloader()
{
	echo -e "\nRebooting to bootloader image ..."
	execute adb reboot-bootloader
}

function reboot_system()
{
	echo -e "\nRebooting to system image ..."
	execute fastboot reboot
}

function wait_bootloader()
{
	echo -en "\nWaiting for bootloader image ...    "
	local interval=$1
	local start=$(date +%s)
	while true; do
		local now=$(date +%s)
		local remaining=$(($interval - $now + $start))
		local devices=$(fastboot devices)
		echo -en '\b\b\b'
		if [[ -n $devices ]]; then
			echo 'OK '
			break
		else
			if [[ $remaining > 0 ]]; then
				printf "%3d" $remaining
				sleep 1
			else
				echo 'timed out'
				exit 1
			fi
		fi
	done
}

function wait_system()
{
	echo -en "\nWaiting for system image ...    "
	local interval=$1
	local start=$(date +%s)
	while true; do
		local now=$(date +%s)
		local remaining=$(($interval - $now + $start))
		local devices=$(adb devices | grep -v 'List of devices')
		echo -en '\b\b\b'
		if [[ -n $devices ]]; then
			echo 'OK '
			break
		else
			if [[ $remaining > 0 ]]; then
				printf "%3d" $remaining
				sleep 1
			else
				echo 'timed out'
				exit 1
			fi
		fi
	done
}

function flash()
{
	echo -e "\nFlashing ..."
	local wipe=
	[[ $opt_wipe == yes ]] && wipe=-w
	if [[ $TARGET_PRODUCT == full_stingray ]]; then
		execute fastboot flash boot $OUT/boot.img
		[[ $opt_dryrun != yes ]] && echo
		execute fastboot flash system $OUT/system.img
		[[ $opt_dryrun != yes ]] && echo
		execute fastboot flash userdata $OUT/userdata.img $wipe
		[[ $opt_dryrun != yes ]] && echo
		execute fastboot erase cache
	else
		execute fastboot flashall $wipe
	fi
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

[[ -z $TARGET_PRODUCT ]] && error "TARGET_PRODUCT not set - have you lunched?"
[[ -z $OUT ]] && error "OUT not set - have you lunched?"

print_banner Starting execution

if [[ $opt_initial_state == system ]]; then
	wait_system 5
	reboot_bootloader
fi

[[ $opt_dryrun != yes ]] && wait_bootloader 30

flash
reboot_system

[[ $opt_dryrun != yes ]] && wait_system 120

