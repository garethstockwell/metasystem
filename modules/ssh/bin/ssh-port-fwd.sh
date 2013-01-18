#!/bin/bash

# Script for forwarding ports over ssh

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/script.sh
source $METASYSTEM_SSH_LIB/port-fwd.sh


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
Usage: $0 <host>
Options:
    --fg, --foreground  Run SSH in foreground
    -h, --help          Print help
    -n, --dry-run       Just print commands, do not execute them
    -q, --quiet         Suppress output

EOF
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Parse command line
arg_host=
opt_fg=no
opt_help=no
opt_quiet=no
for token in "$@"; do
	case $token in
		-fg | --fg | -foreground | --foreground)
			opt_fg=yes
			;;	
		-h | -help | --help)
			opt_help=yes
			;;
		-n | -dry-run | --dry-run)
			opt_dryrun=yes
			;;
		-q | -quiet | --quiet)
			opt_verbosity=silent
			;;
		*)
			if [[ -z $arg_host ]]; then
				arg_host=$token
			else
				warn "Unused argument '$token'"
			fi
			;;
	esac
done

[[ $opt_help == yes ]] && print_usage && exit 0

[[ -z $arg_host ]] && usage_error "No hostname provided"

remote_port_base=$(ssh $arg_host $SSH_PORT_FWD_REMOTE_BASE_CMD)

if [[ $opt_dryrun == no && -z $remote_port_base ]]; then
	echo "Error: failed to get remote port base" >&2
	echo "Check that your server-side .bashrc is not echoing anything for non-interactive shells" >&2
	exit 1
fi

args=

[[ $opt_verbosity != silent ]] && echo "   service local    remote"
for name in $SSH_PORT_FWD_SERVICES; do
	count=$( __ssh_port_fwd_get_field $name count)
	for index in $(seq 1 $count); do
		service=$( __ssh_port_fwd_service_name $name $index)
		local_port=$( __ssh_port_fwd_local_port $remote_port_base $name $index)
		remote_port=$( __ssh_port_fwd_remote_port $remote_port_base $name $index)
		[[ $opt_verbosity != silent ]] &&\
			printf "%10s %5d <-> %5d\n" $service $local_port $remote_port
		args="$args -R${remote_port}:localhost:${local_port}"
	done
done

cmd="ssh $args -n -N $arg_host"

mode=background
[[ $opt_fg == yes ]] && mode=foreground

if [[ $opt_verbosity != silent ]]; then
	echo -e "\nEstablishing $mode ssh connection ..."
	echo $cmd
fi

if [[ $opt_dryrun != yes ]]; then
	if [[ $opt_fg == yes ]]; then
		$cmd
	else
		nohup $cmd >/dev/null 2>/dev/null &
		[[ $? == 0 ]] && echo $!
	fi
fi

