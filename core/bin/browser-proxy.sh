#!/bin/bash

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_NAME=browser-proxy

SCRIPT_VERSION=0.1

SCRIPT_ARGUMENTS='socks_host'

SOCKS_PORT=12345

PATH_PID=~/.browser-proxy.pid


#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

PID_SSH=0
PID_BROWSER=0


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/script.sh


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
    cat << EOF
$USAGE_HEADER

$USAGE_STANDARD_OPTIONS

EOF
}

function parse_command_line()
{
	eval set -- $unused_args

	for token in "$@"; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Unrecognized options
			-*)
			    warn "Unrecognized option $token"
				;;

			# Normal arguments
			*)
				handle_arg $token
				;;
		esac
	done

	check_sufficient_args
}

function socks_chrome {
	open -a /Applications/Google\ Chrome.app/ --args --proxy-server="socks5://127.0.0.1:$SOCKS_PORT"
}

function pid_read()
{
	[[ ! -e $PATH_PID ]] || read PID_SSH PID_BROWSER < $PATH_PID
}

function pid_write()
{
	echo $PID_SSH $PID_BROWSER > $PATH_PID
}

function process_exists()
{
	[[ $1 != 0 ]] && kill -0 $1 > /dev/null 2>&1
}

function start_ssh_tunnel()
{
	if process_exists $PID_SSH; then
		echo "SSH tunnel already running with PID $PID_SSH"
		return
	fi

	ssh -D $SOCKS_PORT $arg_socks_host -N -n >/dev/null 2>&1 &
	PID_SSH=$!
	echo "Started SSH tunnel with PID $PID_SSH"
}

function start_chrome()
{
	if process_exists $PID_BROWSER; then
		echo "Browser already running with PID $PID_BROWSER"
		return
	fi

    local args=--proxy-server="socks5://127.0.0.1:$SOCKS_PORT"
	local chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

	"$chrome" $args >/dev/null 2>&1 &
	PID_BROWSER=$!
	echo "Started browser with PID $PID_BROWSER"
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
    args="$args \"$arg\""
done

parse_standard_arguments $args
parse_command_line

script_preamble

print_standard_summary

pid_read
start_ssh_tunnel
start_chrome
pid_write

