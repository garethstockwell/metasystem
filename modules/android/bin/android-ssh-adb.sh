#!/bin/bash

# Use alias defined in ~/.ssh/config
cmd="ssh android-adb"
metasystem_android_ssh_adb_forward "$@" &&\
echo $cmd &&\
$cmd

