#!/bin/bash

# Wrapper for adb which redirects logcat to a colorizer

case $1 in
	logcat)
		shift
		if [[ $METASYSTEM_OS == windows ]]; then
			adb logcat "$@"
		else
			android-adb-logcat.py "$@"
		fi
		;;
	shell)
		if [[ $METASYSTEM_OS == windows ]]; then
			if [[ -z $2 ]]; then
				# Console2 doesn't handle terminal control codes well
				mintty_dir=
				case $METASYSTEM_PLATFORM in
					mingw)
						mintty_dir=/c/cygwin/bin
						;;
					cygwin)
						mintty_dir=/usr/bin
						;;
				esac
				nohup $mintty_dir/mintty.exe -e adb "$@" &
			else
				# Remove trailing CR
				adb "$@" | tr -d '\015'
			fi
		else
			adb "$@"
		fi
		;;
	*)
		adb "$@"
		;;
esac

