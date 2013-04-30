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
DEFAULT_SSH_PORT=2200


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

for arg in $ARGUMENTS; do
	eval "arg_$arg="
done

opt_kernel=
opt_initrd=
opt_memory=
opt_machine=
opt_ssh_port=
opt_graphics=no
opt_qemu_opts=


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

    --initrd INITRD         Specify initrd
    --kernel KERNEL         Specify kernel
    --memory MEM            Specify memory (default: $DEFAULT_MEMORY)
    --machine MACHINE       Specify machine (default: $DEFAULT_MACHINE)
    --ssh-port PORT         Specify local SSH port (default: $DEFAULT_SSH_PORT)

    --no-graphics           Disable QEMU window
    --graphics              Enable QEMU window

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
			-initrd | --initrd)
				prev=opt_initrd
				;;

            -kernel | --kernel)
				prev=opt_kernel
				;;

			-machine | --machine)
				prev=opt_machine
				;;

			-memory | --memory)
				prev=opt_memory
				;;

			-ssh-port | --ssh-port)
				prev=opt_ssh_port
				;;

			-nographic | --nographic | -no-graphic | --no-graphic | \
			-nographics | --nographics | -no-graphics | --no-graphics)
				opt_graphics=no
				;;

			-graphic | --graphic | \
			-graphics | --graphics)
				opt_graphics=yes
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
	[[ -z $opt_ssh_port ]] && opt_ssh_port=$DEFAULT_SSH_PORT
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Initial ramdisk ......................... $opt_initrd
Kernel .................................. $opt_kernel
Machine ................................. $opt_machine
Memory .................................. $opt_memory
Graphics ................................ $opt_graphics

Additional QEMU options ................. $opt_qemu_opts

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

function find_file()
{
	local name=$1
	local var=opt_$name
	local file=$2
	if [[ -z $(eval echo "\$$var") ]]; then
		local hits=$(find . -iname "$file")
		if [[ -n $hits ]]; then
			if [[ $(echo $hits | wc -w) != 1 ]]; then
				echo "Found multiple instances of $file:"
				for f in $hits; do
					echo -e "\t$f"
				done
				error "Use -$name to disambiguate"
			fi
		fi
		eval "$var=$hits"
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

# Autodetect
find_file initrd rootfs.cpio*
find_file kernel zImage

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

print_banner Starting execution

[[ -z $opt_initrd ]] && warn "No ramdisk image found"
[[ -z $opt_kernel ]] && usage_error "No kernel image found"

qemu_options="
	-M ${opt_machine} -m ${opt_memory} -kernel ${opt_kernel}
	-redir tcp:${opt_ssh_port}::22
	-net nic"

kernel_string="console=ttyAMA0 mem=${opt_memory}"

[[ -n $opt_initrd ]] && qemu_options="$qemu_options -initrd ${opt_initrd}"

if [[ $opt_graphics == yes ]]; then
	qemu_options="$qemu_options -serial stdio"
else
	qemu_options="$qemu_options -nographic"
fi

[[ -n $opt_qemu_options ]] && qemu_options="$qemu_options $opt_qemu_options"

echo -e "qemu-system-arm ${qemu_options}\n\t-append \"${kernel_string}\""

if [[ $opt_graphics == no ]]; then
	echo -e "\nTo exit the emulator, use 'Ctrl-A x'\n"
fi

if [[ $opt_dryrun != yes ]]; then
	qemu-system-arm ${qemu_options} -append "${kernel_string}"
fi

