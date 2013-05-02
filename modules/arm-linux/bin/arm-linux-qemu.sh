#!/bin/bash

# arm-linux-qemu

# Helper script for launching QEMU, with Linux guest
# Exports rootfs to the guest via NFS
# Sets up host-guest networking via TUN/TAP

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/list.sh
source $METASYSTEM_CORE_LIB_BASH/misc.sh
source $METASYSTEM_CORE_LIB_BASH/script.sh
source $METASYSTEM_ARM_LINUX_LIB_BASH/misc.sh
source $METASYSTEM_ARM_LINUX_LIB_BASH/comms.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

VALID_ACTIONS='setup launch'
DEFAULT_ACTION=launch

DEFAULT_MEMORY=128M
DEFAULT_MACHINE=versatilepb

DEFAULT_SSH_HOST_PORT=1022
DEFAULT_GDB_HOST_PORT=1033

SSH_GUEST_PORT=22
GDB_GUEST_PORT=2345

IFUP_SCRIPT=$PWD/scripts/qemu-ifup.sh


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

arg_action=

opt_kernel=
opt_initrd=
opt_memory=
opt_machine=
opt_ssh_port=
opt_graphics=no
opt_rootfs=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	# [CHANGE] Modify descriptions of arguments and options
	cat << EOF
arm-linux-qemu script

Usage: $0 [options] <action>

Default values for options are specified in brackets.

Valid actions: $VALID_ACTIONS

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
    --ssh-port PORT         Specify host SSH port (default: $DEFAULT_SSH_HOST_PORT)
    --gdb-port PORT         Specify host GDB port (default: $DEFAULT_GDB_HOST_PORT)
    --rootfs ROOTFS         Specify rootfs

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
			-rootfs | --rootfs)
				prev=opt_rootfs
				;;

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

			-gdb-port | --gdb-port)
				prev=opt_gdb_port
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
				if [[ -z $arg_action ]]; then
					arg_action=$token
				else
					warn "Additional argument '$token' ignored"
				fi
				;;
		esac
	done

	if [[ -n $arg_action ]]; then
		[[ -z $(list_contains $arg_action $VALID_ACTIONS) ]] &&\
			usage_error "Invalid action '$arg_action'"
	else
		arg_action=$DEFAULT_ACTION
	fi

	# Set defaults
	[[ -z $opt_machine ]] && opt_machine=$DEFAULT_MACHINE
	[[ -z $opt_memory ]] && opt_memory=$DEFAULT_MEMORY
	[[ -z $opt_ssh_port ]] && opt_ssh_port=$DEFAULT_SSH_HOST_PORT
	[[ -z $opt_gdb_port ]] && opt_gdb_port=$DEFAULT_GDB_HOST_PORT
	[[ -z $opt_rootfs ]] && opt_rootfs=$ARM_LINUX_ROOTFS
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Action .................................. $arg_action

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Machine ................................. $opt_machine
Memory .................................. $opt_memory
Graphics ................................ $opt_graphics

Kernel .................................. $opt_kernel

Initial ramdisk ......................... $opt_initrd
rootfs .................................. $opt_rootfs

SSH host port ........................... $opt_ssh_port
GDB host port ........................... $opt_gdb_port

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
# Guts
#------------------------------------------------------------------------------

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
# Actions
#------------------------------------------------------------------------------

function action_setup()
{
	print_banner "Configuring host"
	assert_superuser
	check_rootfs $opt_rootfs
	generate_ifup_script $IFUP_SCRIPT
	nfs_export $opt_rootfs
	create_tap
}

function action_launch()
{
	print_banner "Launching QEMU"

	[[ -z $opt_kernel ]] && usage_error "No kernel image found"
	if [[ -n $opt_rootfs ]]; then
		check_rootfs $opt_rootfs
	else
		[[ -z $opt_initrd ]] && warn "No ramdisk image found"
	fi

	local qemu_options="
	-M ${opt_machine} -m ${opt_memory}
	-kernel ${opt_kernel}
	-redir tcp:${opt_ssh_port}::$SSH_GUEST_PORT
	-redir tcp:${opt_gdb_port}::$GDB_GUEST_PORT"

	local kernel_string="console=ttyAMA0 mem=${opt_memory}"

	# Graphics
	if [[ $opt_graphics == yes ]]; then
		qemu_options=$(echo -e "$qemu_options\n\t-serial stdio")
	else
		qemu_options=$(echo -e "$qemu_options\n\t-nographic")
	fi

	# NFS
	local net_opts="-net nic"
	if [[ -n $opt_rootfs ]]; then
		net_opts="-net nic,vlan=0 -net tap,ifname=tap0,script=$IFUP_SCRIPT"
		kernel_string="$kernel_string root=/dev/nfs rw nfsroot=$host_ip:$opt_rootfs ip=$vm_ip:$host_ip:$host_gateway:$host_mask"
	else
		[[ -n $opt_initrd ]] && qemu_options=$(echo -e "$qemu_options\n\t-initrd ${opt_initrd}")
	fi
	qemu_options=$(echo -e "$qemu_options\n\t$net_opts")

	# Echo
	echo -e "qemu-system-arm ${qemu_options}\n\t-append \"${kernel_string}\""
	if [[ $opt_graphics == no ]]; then
		echo -e "\nTo exit the emulator, use 'Ctrl-A x'\n"
	fi

	# Launch
	if [[ $opt_dryrun != yes ]]; then
		qemu-system-arm ${qemu_options} -append "${kernel_string}"
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

query_host_network

eval action_${arg_action//-/_}

