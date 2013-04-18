#!/bin/bash

# Transcode a short clip for testing on Android emulator

exe=avconv
[[ -z $(which $exe) ]] && exe=ffmpeg

in_file=$1
out_file=$2

$exe \
	-i $in_file \
	-vcodec libx264 -b 1000k \
	-acodec aac -ar 32000 -ab 128k -ac 2 \
	-strict experimental \
	-t 00:01:00 \
	$out_file

