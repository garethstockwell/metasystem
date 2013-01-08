#!/bin/sh

# Compatibility script for systems which lack tput
# http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html

command=$1
shift

case $command in
	setab)
		echo "TODO"
		;;

	setaf)
		echo "TODO"
		;;

	*)
		echo "Error: command $command not supported" >&2
		exit 1
		;;
esac


