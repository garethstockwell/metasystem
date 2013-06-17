#!/bin/sh

IP_TUN=10.1.10.1
IP_VM=10.1.193.200

sudo /sbin/ifconfig $1 $IP_TUN
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/ip_forward'
sudo route add -host $IP_VM dev tap0
sudo bash -c 'echo 1 >/proc/sys/net/ipv4/conf/tap0/proxy_arp'
sudo arp -Ds $IP_VM eth0 pub

