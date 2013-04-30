#!/bin/bash

# arm-linux-qemu

# TODO
# NFS
#	- Set NFS root
#	- Write qemu-ifup.sh into $NFS/sbin
#	- Helpers for setting up server?

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

TUN_IP_LEAF=150
QEMU_IP_LEAF=200

QEMU_IFUP=qemu-ifup.sh

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
opt_nfs=no


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

    --no-nfs                Disable NFS sharing
    --nfs                   Enable NFS sharing

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

			-no-nfs | --no-nfs)
				opt_nfs=no
				;;

			-nfs | --nfs)
				opt_nfs=yes
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
NFS ..................................... $opt_nfs

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

function query_host_network()
{
	print_banner "Network information"
	host_ip=$(ifconfig | grep 'inet addr' | head -n1 | awk ' { print $2 } ' | sed -e 's/addr://')
	host_gateway=$(route -n | head -n3 | tail -n1 | awk '{ print $2 }')
	host_mask='255.255.255.0'
	qemu_ip=${host_ip%*.*}.${QEMU_IP_LEAF}
	tun_ip=${host_ip%*.*}.${TUN_IP_LEAF}

	echo "Host IP address ............... $host_ip"
	echo "Host gateway .................. $host_gateway"
	echo "Host mask ..................... $host_mask"
	echo "QEMU IP address ............... $qemu_ip"
	echo "TUN IP address ................ $tun_ip"
}

function generate_ifup()
{
	print_banner "ifup"
	cat << EOF
#!/bin/sh

IP_TUN=$tun_ip
IP_QEMU=$qemu_ip

sudo /sbin/ifconfig \$1 \$IP_TUN
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/ip_forward'
sudo route add -host \$IP_QEMU dev tap0
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/conf/tap0/proxy_arp'
sudo arp -Ds \$IP_QEMU eth0 pub

EOF
}

function launch_qemu()
{
	print_banner "Launching QEMU"

	local qemu_options="
	-M ${opt_machine} -m ${opt_memory}
	-kernel ${opt_kernel}
	-redir tcp:${opt_ssh_port}::22"

	local kernel_string="console=ttyAMA0 mem=${opt_memory}"

	# Graphics
	if [[ $opt_graphics == yes ]]; then
		qemu_options=$(echo -e "$qemu_options\n\t-serial stdio")
	else
		qemu_options=$(echo -e "$qemu_options\n\t-nographic")
	fi

	# NFS
	local net_opts="-net nic"
	if [[ $opt_nfs == yes ]]; then
		net_opts="-net ic,vlan=0 -net tap,ifname=tap0,script=$QEMU_IFUP"
		kernel_string="$kernel_string root=/dev/nfs rw nfsroot=$host_ip:$rfs ip=$qemu_ip:$host_ip:$host_gateway:$host_mask"
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

[[ -z $opt_initrd ]] && warn "No ramdisk image found"
[[ -z $opt_kernel ]] && usage_error "No kernel image found"

query_host_network
generate_ifup
launch_qemu

