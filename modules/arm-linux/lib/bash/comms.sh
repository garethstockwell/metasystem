# comms.sh

# Functions concerned with host-VM communication
# - rootfs export via NFS
# - host-VM networking via TUN/TAP

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

TUN_IP_LEAF=10.1
VM_IP_LEAF=200


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function nfs_export()
{
	local path=$1
	echo "Appending $path to /etc/exports ..."
	assert_superuser
	if [[ $opt_dryrun != yes ]]; then
		rm -f /tmp/exports
		mv /etc/exports /tmp/exports
		cat /tmp/exports | grep -v $path > /etc/exports
		sh -c "echo \"$path 192.168.0.0/255.255.0.0(rw,sync,no_root_squash,no_subtree_check,insecure)\" >> /etc/exports"
	fi
	execute exportfs -ra
}

function query_host_network()
{
	print_banner "Network information"
	host_ip=$(ifconfig | grep 'inet addr' | head -n1 | awk ' { print $2 } ' | sed -e 's/addr://')
	host_gateway=$(route -n | head -n3 | tail -n1 | awk '{ print $2 }')
	host_mask='255.255.255.0'
	vm_ip=${host_ip%*.*}.${VM_IP_LEAF}
	tun_ip=${host_ip%*.*.*}.${TUN_IP_LEAF}

	echo "Host IP address ............... $host_ip"
	echo "Host gateway .................. $host_gateway"
	echo "Host mask ..................... $host_mask"
	echo "VM IP address ................. $vm_ip"
	echo "TUN IP address ................ $tun_ip"
}

function create_tap()
{
	echo -e "\nCreating tap0 ..."
	assert_superuser
	[[ -z $tun_ip ]] && error "tun_ip not set: forgot to call query_host_network?"
	execute tunctl -u $(logname)
	execute ifconfig tap0 $tun_ip up
}

function generate_ifup_script()
{
	local script=$1
	echo -e "\nCreating $script ..."
	mkdir -p $(dirname $script)
	cat > $script << EOF
#!/bin/sh

IP_TUN=$tun_ip
IP_VM=$vm_ip

sudo /sbin/ifconfig \$1 \$IP_TUN
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/ip_forward'
sudo route add -host \$IP_VM dev tap0
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/conf/tap0/proxy_arp'
sudo arp -Ds \$IP_VM eth0 pub

EOF
}

