#!/bin/sh

DIR=~/work/local/etc/openvpn
CONFIG=client.ovpn
LOG=openvpn.log

get_pid()
{
	ps ax | grep openvpn | grep $CONFIG | awk '{print $1}'
}

do_connect()
{
	local pid=$(get_pid)
	if [ -z "$pid" ]
	then
		echo "Connecting ..."
		cd $DIR && sudo openvpn --config ./$CONFIG --log ./$LOG --daemon
		echo "Connected with PID $(get_pid)"
	else
		echo "Already connected (PID $pid)"
	fi
}

do_disconnect()
{
	local pid=$(get_pid)
	if [ ! -z "$pid" ]
	then
		echo "Disconnecting PID $pid ..."
		sudo kill -9 $pid
	fi
}

op=$1
case $op in
	connect)
		do_connect
		;;
	disconnect)
		do_disconnect
		;;
	*)
		echo "Usage: $0 [connect|disconnect]"
		exit 1
esac

