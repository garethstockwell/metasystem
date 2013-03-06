#!/usr/bin/env bash

# Prints the launchable activity for an APK
# So you can do
#
# adb install mk.apk
# adb shell am start $(android-launchable.sh my.apk)

apk=$1

[[ -z $apk ]] && echo "Usage: $0 [apk]" >&2 && exit 1
[[ ! -e $apk ]] && echo "Error: APK file $apk not found" >&2 && exit 1

package=$(aapt dump badging $apk |\
	grep package |\
	awk '{ print $2 }' |\
	sed -e "s/'//g" |\
	sed -e 's/name=//')

activity=$(aapt dump badging $apk |\
	grep launchable |\
	awk '{ print $2 }' |\
	sed -e "s/'//g" |\
	sed -e 's/name=//')

echo $package/$activity

