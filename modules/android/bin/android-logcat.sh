#!/usr/bin/env bash

# Capture Android log into a uniquely named file

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

LOG_FILENAME_FORMAT='alog_%02d.txt'


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function get_filename()
{
	local i=1
	while (true); do
		local file=$(printf $LOG_FILENAME_FORMAT $i)
		i=$((i+1))
		if [[ ! -e $file ]]; then
			echo $file
			break
		fi
	done
}

# Print an error message and exit
function error()
{
    echo -e "\nError: $*" >&2
    if [[ "$opt_dryrun" != yes ]]; then
        exit 1
    fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

file=$(get_filename)
echo -e "Log filename $file" >&2

echo -en "Waiting for device ... " >&2
adb wait-for-device
echo -e "OK" >&2

devices=$(android-devices.sh)
[[ -z $devices ]] && error "No ADB device found"
[[ $(echo $devices | wc -w) != 1 ]] && error "Multiple ADB devices found: $devices"

echo -e "Clearing device log ..." >&2
adb shell logcat -c

echo -e "Starting logcat ..." >&2
adb logcat -v threadtime | tee $file

