#!/bin/bash

# Transcode a short clip for testing on Android emulator
# http://developer.android.com/guide/appendix/media-formats.html

function usage_error()
{
	local msg=$1
	echo "Usage: $0 <in> <codec> <out>" >&2
	[[ -z $msg ]] || echo $msg >&2
	exit 1
}

function check_container()
{
	local ext=$1
	shift
	local codec=$1
	shift
	valid="$@"
	for v in $valid; do
		[[ $ext == $v ]] && return
	done
	usage_error "Invalid container format '$ext' for codec $codec (valid: $valid)"
}

exe=avconv
[[ -z $(which $exe) ]] && exe=ffmpeg

in_file=$1
video_codec=$2
out_file=$3

[[ -n $out_file ]] || usage_error

out_name=$(basename "$out_file")
out_ext="${out_name##*.}"

echo "out_ext=$out_ext"

case $video_codec in
	h263)
		check_container $out_ext $video_codec 3gp mp4
		video_args='-c:v h263 -vf scale=704x576'
		;;
	h264)
		check_container $out_ext $video_codec mp4
		video_args='-c:v libx264 -profile:v baseline -level 1'
		;;
	*)
		usage_error "Invalid codec $video_codec (valid: h263, h264)"
esac

$exe \
	-i $in_file \
	$video_args \
	-c:a aac -ar 32000 -ab 128k -ac 2 \
	-strict experimental \
	-t 00:01:00 \
	$out_file

