#!/bin/bash

ANDROID_DEVICE_HOME=$METASYSTEM_ANDROID_ROOT/device

function push_files()
{
	local src=$1
	local dest=$2
	android-sync.sh $src $dest -push
	# Ignore errors
	return 0
}

android-setup-ssh.sh &&\
android-ssh-adb-forward.sh &&\
push_files $ANDROID_DEVICE_HOME/home /sdcard &&\
push_files $ANDROID_DEVICE_HOME/data /data

