#!/bin/bash

# arm-linux-qemu

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/script.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

DEFAULT_MEMORY=128M
DEFAULT_MACHINE=versatilepb


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

for arg in $ARGUMENTS; do
	eval "arg_$arg="
done

opt_kernel=
opt_memory=
opt_machine=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	# [CHANGE] Modify descriptions of arguments and options
	cat << EOF
arm-linux-qemu script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --kernel KERNEL         Specify kernel
    --memory MEM            Specify memory (default: $DEFAULT_MEMORY)
    --machine MACHINE       Specify machine (default: $DEFAULT_MACHINE)

EOF
}

function print_version()
{
	cat << EOF
arm-linux-qemu script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $*
	parse_standard_arguments "$@"

	for token in $unused_args; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			-machine | --machine)
				prev=opt_machine
				;;

			-memory | --memory)
				prev=opt_memory
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

	# Set defaults
	[[ -z $opt_machine ]] && opt_machine=$DEFAULT_MACHINE
	[[ -z $opt_memory ]] && opt_memory=$DEFAULT_MEMORY
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Kernel .................................. $opt_kernel
Machine ................................. $opt_machine
Memory .................................. $opt_memory

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


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_command_line $args

if [[ -z $opt_kernel ]]; then
	opt_kernel=$(find . -iname zImage)
fi

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

print_banner Starting execution

execute qemu-system-arm -M $opt_machine -m $opt_memory -kernel $opt_kernel

