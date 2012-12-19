#!/bin/bash

cmd="adb forward tcp:$ANDROID_HOST_SSH_PORT tcp:$ANDROID_TARGET_SSH_PORT $@"
echo $cmd &&\
$cmd

