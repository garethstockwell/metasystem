#!/bin/bash

# Wrapper for adb which redirects logcat to a colorizer

logcat=
[[ $1 == logcat ]] && shift && logcat=1
if [[ -n $logcat ]]; then
	android-adb-logcat.py "$@"
else
	adb "$@"
fi

