#!/bin/bash

# Transcode a short clip for testing on Android emulator

in_file=$1
out_file=$2

avconv \
	-i $in_file \
	-vcodec mpeg4 -b 1000k \
	-acodec ac3 -ar 32000 -ab 128k -ac 2 \
	-t 00:01:00 \
	$out_file

