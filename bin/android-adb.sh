#!/bin/bash

# Wrapper for adb which redirects logcat to a colorizer

case $1 in
	logcat)
		shift
		android-adb-logcat.py "$@"
		;;
	shell)
		# Console2 doesn't handle terminal control codes well
		if [[ $METASYSTEM_OS == windows ]]; then
			nohup mintty -e adb "$@" &
		else
			adb "$@"
		fi
		;;
	*)
		adb "$@"
		;;
esac

