#!/bin/bash

# video-capture

# Script for capturing video from the screen (via xvidcap) or from a camera
# (via mencoder)

#------------------------------------------------------------------------------
# TODO
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='output'

DEFAULT_FRAME_RATE=30
DEFAULT_WIDTH=1280
DEFAULT_HEIGHT=720

VALID_SOURCES='screen camera'
DEFAULT_SOURCE='camera'

VALID_IMAGE_CODECS='jpg png ppm tga'
VALID_VIDEO_CODECS='ffv1 mpeg webm'
VALID_CODECS="$VALID_IMAGE_CODECS $VALID_VIDEO_CODECS"
DEFAULT_CODEC='ffv1'

# Format to which xvidcap writes
RAW_IMAGE_CODEC='xwd'

# Format to which raw frames are converted, prior to encoding into a video
# stream
DEFAULT_INTERMEDIATE_IMAGE_CODEC='tga'

CONTAINERS='
png:png
ppm:ppm
jpg:jpg
tga:tga
ffv1:avi
mpeg:avi
webm:webm
'

# Input image formats supported by mencoder
# These, together with the value of RAW_IMAGE_CODEC, are used to determine
# whether raw images need to be converted using ImageMagick before encoding
# using mencoder
MENCODER_IMAGE_CODECS='jpg tga png'

MENCODER_VCODECS='
ffv1:ffv1
mpeg:mpeg4
webm:libvpx
'

RESOLUTIONS='
nHD:640x360
qHD:960x540
360p:640x360
480p:854x480
720p:1280x720
1080p:1900x1080
'
DEFAULT_RESOLUTION='720p'

DEFAULT_CAMERA_DEVICE='/dev/video0'

DEFAULT_TMP_DIR=~/.video-capture

# Number of convert processes which are spawned
IMAGEMAGICK_MAX_PROCESSES=16

# Limits for ImageMagick commands
IMAGEMAGICK_MAX_MEMORY=10000000
IMAGEMAGICK_MAX_FILES=10
IMAGEMAGICK_MAX_THREADS=8

# Max number of files to give to convert at one time
IMAGEMAGICK_CONVERT_MAX_INPUT_IMAGES=8

# Delay used in the wait loop while convert operations are running
WAITALL_DELAY=1

CONVERT_PARALLEL=no


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_debug=no
opt_dryrun=no
opt_force=no
opt_help=
opt_version=
opt_verbosity=normal

opt_fps=$DEFAULT_FRAME_RATE
opt_resolution=default
opt_width=
opt_height=
opt_source=$DEFAULT_SOURCE
opt_codec=$DEFAULT_CODEC
opt_camera_device=$DEFAULT_CAMERA_DEVICE
opt_raw=yes
opt_tmp_dir=$DEFAULT_TMP_DIR

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Printing functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
	echo -e "\nError: $*"
	if [ "$opt_dryrun" != yes ]
	then
		exit 1
	fi
}

function warn()
{
	echo "Warning: $*"
}

function usage_error()
{
	echo -e "Error: $*\n"
	print_usage
	exit 1
}

function print_rule()
{
	test "$opt_verbosity" != silent && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [ "$opt_verbosity" != silent ]
	then
		echo
		print_rule
		echo $*
		print_rule
	fi
}

function print_message()
{
	if [ "$opt_verbosity" != silent ]
	then
		echo
		echo -n $*
		echo ' ...'
	fi
}

function print_version()
{
	cat << EOF
video-capture script version $SCRIPT_VERSION
EOF
}

#------------------------------------------------------------------------------
# Subshell functions
#------------------------------------------------------------------------------

# Execute shell command; abort script if command fails
function execute()
{
	cmd=$*
	test "$opt_verbosity" != silent && echo "$cmd"
	if [ "$opt_dryrun" != yes ]
	then
		$cmd
		r=$?
		if [ "$r" != 0 ]
		then
			error Execution of \"$cmd\" failed: exit code $r
		fi
	fi
}

#------------------------------------------------------------------------------
# List and hash functions
#------------------------------------------------------------------------------

function list_contains()
{
	local element=$1
	shift
	local list="$*"
	local result=
	for x in $list
	do
		test "$x" == "$element" && result=1
	done
	echo $result
}

function get_keys()
{
	local list="$*"
	local result=
    for x in $list
	do
		local key=`echo $x | sed -e 's/:.*//'`
		test -n "$result" && result="$result "
		result="$result$key"
	done
	echo $result
}

function get_value()
{
	local key=$1
	shift
	local list="$*"
	local result=
	for x in $list
	do
		local list_key=`echo $x | sed -e 's/:.*//'`
		local value=`echo $x | sed -e 's/.*://'`
		test "$key" == "$list_key" && result=$value
	done
	echo $result
}

function list_pipe_separated()
{
	local list="$*"
	echo $list | sed -e 's/ /|/g'
}

# Separate list into N chunks
# For input 'a b c d e f g h' with N=3, output is
# a,b,c|d,e,f|g,h
# This can be looped over as follows:
# for chunk in ${chunks//|/ }
# do
#	echo $chunk
#	for element in ${chunk//,/ }
#	do
#		echo $element
#	done
# done
function chunk_list()
{
	local n_chunks=$1
	shift
	local input_list=$*
	local input=($input_list)
	local i=0
	local chunk_size=$(expr 1 + ${#input[@]} / $n_chunks)
	local output=
	local chunk_count=0
	while [ $i -lt ${#input[@]} ]
	do
		local element=${input[$i]}
		if [ $chunk_count == $chunk_size ]
		then
			output="$output|"
			chunk_count=0
		else
			test -n "$output" && output="$output,"
		fi
		output="$output$element"
		((++chunk_count))
		((++i))
	done
	echo $output
}

#------------------------------------------------------------------------------
# Timing functions
#------------------------------------------------------------------------------

function get_time()
{
	local t=$(date +%s)
	echo $t
}

function start_timer()
{
	local start_time_var=timer_start_$1
	eval $start_time_var=\$\(get_time\)
}

function elapsed_time()
{
	local start_time_var=timer_start_$1
	local start_time=$(eval echo \$$start_time_var)
	local end_time=$(get_time)
	local elapsed_time="$(expr $end_time - $start_time)"
	echo $elapsed_time
}

function stop_timer()
{
	local label=$1
	if [ "$opt_dryrun" != "yes" ]
	then
		echo -n "Elapsed time $(elapsed_time $label)s"
		# Note: extra spaces are to overwrite wait_pids output
		echo "                                                                 "
	fi
}

#------------------------------------------------------------------------------
# Misc utility functions
#------------------------------------------------------------------------------

function get_codec_type()
{
	local codec=$1
	test -n "$(list_contains $codec $VALID_IMAGE_CODECS)" &&\
		echo 'image'
	test -n "$(list_contains $codec $VALID_VIDEO_CODECS)" &&\
		echo 'video'
}

#------------------------------------------------------------------------------
# Command line parsing
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
video-capture script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    output                  Output directory or file

Options:
    -d, --debug             Do not remove temporary files
    -f, --force             Force (overwrite existing files)
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --screen                Capture from screen
    --no-raw                Capture directly to encoded images/video
    --raw                   Capture raw images

    --camera                Capture from camera (default)
    --camera-device DEVICE  Camera device (default: $DEFAULT_CAMERA_DEVICE)

    --codec                 Output codec
                                [$(list_pipe_separated $VALID_CODECS)]
                                (default: $DEFAULT_CODEC)

    --fps FPS               Frame rate (default: $DEFAULT_FRAME_RATE)

    --resolution RESOLUTION Capture resolution
                                [$(list_pipe_separated $(get_keys $RESOLUTIONS))]
                                (default: $DEFAULT_RESOLUTION)
    --width WIDTH           Capture width      (default: $DEFAULT_HEIGHT)
    --height HEIGHT         Capture height     (default: $DEFAULT_WIDTH)

    --tmp-dir DIR           Location for temporary files (default: $DEFAULT_TMP_DIR)

EOF
}

function parse_command_line()
{
	eval set -- $*
	for token in "$@"
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-d | -debug | --debug)
			    opt_debug=yes
				;;
			-f | -force | --force)
			    opt_force=yes
				;;
			-h | -help | --help | -usage | --usage)
				opt_help=yes
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				opt_dryrun=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				opt_verbosity=silent
				;;
			-v | -verbose | --verbose)
				opt_verbosity=verbose
				;;
			-V | -version | --version)
				opt_version=yes
				;;

			-screen | --screen)
				opt_source=screen
				;;

			-no-raw | --no-raw)
				opt_raw=no
				;;

			-raw | --raw)
				opt_raw=yes
				;;

			-camera | --camera)
				opt_source=camera
				;;

			-codec | --codec)
				prev=opt_codec
				;;
			-codec=* | --codec=*)
				opt_codec=$optarg
				;;

			-camera-device | --camera-device)
				prev=opt_camera_device
				;;
			-camera-device=* | --camera-device=*)
				opt_camera_device=$optarg
				;;

			-fps | --fps)
				prev=opt_fps
				;;
			-fps=* | --fps=*)
				opt_fps=$optarg
				;;

			-resolution | --resolution)
				prev=opt_resolution
				;;
			-resolution=* | --resolution=*)
				opt_resolution=$optarg
				;;

			-width | --width)
				prev=opt_width
				;;
			-width=* | --width=*)
				opt_width=$optarg
				;;
			-height | --height)
				prev=opt_height
				;;
			-height=* | --height=*)
				opt_height=$optarg
				;;

			-tmp-dir | --tmp-dir)
				prev=opt_tmp_dir
				;;
			-tmp-dir=* | --tmp-dir=*)
				opt_tmp_dir=$optarg
				;;

			# Environment variables
			*=*)
				envvar=`expr "x$token" : 'x\([^=]*\)='`
				optarg=`echo "$optarg" | sed "s/'/'\\\\\\\\''/g"`
				eval "$envvar='$optarg'"
				export $envvar
				;;

			# Unrecognized options
			-*)
				warn "Unrecognized option '$token' ignored"
				;;

			# Normal arguments
			*)
				local arg_used=
				for arg in $ARGUMENTS
				do
					if [ -z `eval "echo \\$arg_$arg"` ]
					then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				test -z "$arg_used" && warn "Additional argument '$token' ignored"
				;;
		esac
	done

	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $ARGUMENTS
	do
		if [ -z `eval "echo \\$arg_$arg"` ]
		then
			args_supplied=
			break
		fi
	done
	test -z "$args_supplied" && usage_error 'Insufficient arguments provided'

	# Validate
	test -z $(list_contains $opt_source $VALID_SOURCES) &&\
		usage_error "Invalid source type"
	test -z $(list_contains $opt_codec $VALID_CODECS) &&\
		usage_error "Invalid codec"

	if [ "$opt_resolution" == "default" ]
	then
		if [ ! -z "$opt_width" -o ! -z "$opt_height" ]
		then
			test -z "$opt_width" && opt_width=$DEFAULT_WIDTH
			test -z "$opt_height" && opt_height=$DEFAULT_HEIGHT
		else
			opt_resolution=$DEFAULT_RESOLUTION
		fi
	fi
	test "$opt_resolution" != "default" && parse_resolution
}

function check_output()
{
	case $codec_type in
		image)
			test ! -d $arg_output && error "Output directory $arg_output not found"
			;;
		video)
			test -e $arg_output -a "$opt_force" != "yes" && \
				error "Output file $arg_output already exists"
			local suffix=
			local maybe_suffix=`echo $arg_output | sed -e 's/.*\.//'`
			test -n "$maybe_suffix" -a "$maybe_suffix" != "$arg_output" && suffix=$maybe_suffix
			test "$suffix" != "$container" && \
				echo "Warning: output file suffix [$suffix] does not match container [$container]"
			;;
	esac

	# Convert relative to absolute path
	local abs_output_dir=`cd $(dirname $arg_output) && pwd`
	local output_file=$(basename $arg_output)
	arg_output=$abs_output_dir
	test -n "$output_file" && arg_output=$abs_output_dir/$output_file
}

function parse_resolution()
{
	local resolution=$(get_value $opt_resolution $RESOLUTIONS)
	test -z "$resolution" && usage_error "Invalid resolution"
	opt_width=`echo $resolution | sed -e 's/x.*//'`
	opt_height=`echo $resolution | sed -e 's/.*x//'`
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Dry run ................................. $opt_dryrun
Debug ................................... $opt_debug
Force ................................... $opt_force
Verbosity ............................... $opt_verbosity

Source .................................. $opt_source
Frame rate .............................. $opt_fps
Frame size .............................. $opt_width x $opt_height
Codec ................................... $opt_codec ($codec_type)
Container ............................... $container
Camera device ........................... $opt_camera_device
Raw capture ............................. $opt_raw
Temporary directory ..................... $opt_tmp_dir

ImageMagick resource limits
Parallel conversion ..................... $CONVERT_PARALLEL
Max input images per invocation ......... $IMAGEMAGICK_CONVERT_MAX_INPUT_IMAGES
Max memory /bytes ....................... $IMAGEMAGICK_MAX_MEMORY
Max files ............................... $IMAGEMAGICK_MAX_FILES
Max processes ........................... $IMAGEMAGICK_MAX_PROCESSES
Max threads ............................. $IMAGEMAGICK_MAX_THREADS

EOF

for arg in $ARGUMENTS
do
	local arg_len=${#arg}
	let num_dots=total_num_dots-arg_len
	local value=`eval "echo \\$arg_$arg"`
	echo -n "$arg "
	awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
	echo " $value"
done
}

#------------------------------------------------------------------------------
# Capture / conversion functions
#------------------------------------------------------------------------------

function capture_screen()
{
	print_message Capturing from screen
    cmd="xvidcap --sf --fps $opt_fps --audio no --cap_geometry ${opt_width}x${opt_height}"
	if [ "$opt_raw" == "yes" ]
	then
		cmd="$cmd --file frame-%04d.$RAW_IMAGE_CODEC"
		start_timer capture_screen
		execute $cmd
		stop_timer capture_screen
		if [ "$codec_type" == "image" ]
		then
			convert_images $codec
		else
			encode_images
		fi
	else
		if [ "$codec_type" == "image" ]
		then
			cmd="$cmd --file frame-%04d.$container"
		else
			cmd="$cmd --codec $opt_codec --file $arg_output"
		fi
		start_timer capture_screen
		execute $cmd
		stop_timer capture_screen
	fi
}

function mencoder_options()
{
	cmd="-ovc lavc -lavcopts"
	local vcodec=$(get_value $opt_codec $MENCODER_VCODECS)
	cmd="$cmd vcodec=$vcodec"
	cmd="$cmd -o $arg_output"
	echo $cmd
}

function capture_camera()
{
	print_message Capturing from camera
	cmd="mencoder tv:// -tv driver=v4l2:width=${opt_width}:height=${opt_height}:device=${opt_camera_device}"
	cmd="$cmd -nosound"
	cmd="$cmd -fps ${opt_fps}"
	cmd="$cmd $(mencoder_options)"
	start_timer capture_camera
	execute $cmd
	stop_timer capture_camera
}

# http://stackoverflow.com/questions/356100/how-to-wait-in-bash-for-several-subprocesses-to-finish-and-return-exit-code-0
function wait_pids()
{
	local $image_codec=$1
	shift
	local pid_count=$#
	while :;
	do
		# Check on progress
		raw_count=`find $tmp_dir -iname "*.$RAW_IMAGE_CODEC" | wc -l`
		magick_count=`find $tmp_dir -iname 'magick*' | wc -l`
		output_count=`find $tmp_dir -iname "*.$image_codec" | wc -l`
		tmp_size=`du -hs $tmp_dir 2>/dev/null | awk '{ print $1 }'`
		printf "elapsed %4ds processes %2d/%2d raw %3d magick %3d output %3d tmp_size %5s" \
			$(elapsed_time) $# $pid_count $raw_count $magick_count $output_count $tmp_size
		for pid in "$@"
		do
			shift
			if kill -0 "$pid" 2>/dev/null
			then
				# pid is still alive
				set -- "$@" "$pid"
			elif wait "$pid"
			then
				# pid exited with zero exit status
				test "$opt_verbosity" == "verbose" &&\
					echo "Child $pid exited with zero exit status"
			else
				echo "Child $pid exited with non-zero exit status"
			fi
		done
		(("$#" > 0)) || break
		# Move cursor back to start of line
		echo -en "\r"
		sleep ${WAITALL_DELAY:-1}
	done
}

function convert_images()
{
	local image_codec=$1
	print_message Converting images from $RAW_IMAGE_CODEC to $image_codec
	local input=
	test "$opt_dryrun" != "yes" && input=`'ls' -1 *.$RAW_IMAGE_CODEC`
	local count=`echo $input | wc -w`
	echo "$count frames"
	local dir=
	test "$codec_type" == "image" && dir="$arg_output/"

	export MAGICK_FILE_LIMIT=$IMAGEMAGICK_MAX_FILES
	export MAGICK_MAP_LIMIT=$IMAGEMAGICK_MAX_MEMORY
	export MAGICK_MEMORY_LIMIT=$IMAGEMAGICK_MAX_MEMORY
	export MAGICK_THREAD_LIMIT=$IMAGEMAGICK_MAX_THREADS
	export MAGICK_TEMPORARY_PATH=$tmp_dir

	if [ "$opt_dryrun" != "yes" ]
	then
		if [ "$CONVERT_PARALLEL" == "yes" ]
		then
			convert_images_parallel $image_codec $input
		else
			convert_images_serial $image_codec $input
		fi
	fi
}

function convert_images_serial()
{
	echo "Converting images in serial batches ..."
	local image_codec=$1
	shift
	local input=$*
	local input_count=`echo $input | wc -w`
	local n_chunks=$(expr $input_count / $IMAGEMAGICK_CONVERT_MAX_INPUT_IMAGES)
	local chunks=$(chunk_list $n_chunks $input)
	local chunk_index=0
	start_timer convert_images_serial
	for chunk in ${chunks//|/ }
	do
		local output=$(printf "${dir}frame-%04d-%%04d.$image_codec" $chunk_index)
		local elements=${chunk//,/ }
		local cmd="convert $elements $output"
		((++chunk_index))
		echo -n "Converting batch $chunk_index / $n_chunks ...               "
		$cmd
		echo -en "\r"
	done
	stop_timer convert_images_serial
	echo
}

function convert_images_parallel()
{
	echo "Converting images in parallel batches ..."
	local image_codec=$1
	shift
	local input=$*
	local chunks=$(chunk_list $IMAGEMAGICK_MAX_PROCESSES $input)
	local pids=
	# Spawn processes
	for chunk in ${chunks//|/ }
	do
		local output=$(printf "${dir}frame-%04d-%%04d.$image_codec" $chunk_index)
		local elements=${chunk//,/ }
		local cmd="convert $elements $output"
		$cmd &
		local pid=$!
		pids="$pids $pid"
	done

	local pid_count=`echo $pids | wc -w`
	echo "Started $pid_count child processes"

	# Wait for child processes to complete
	start_timer convert_images_parallel
	wait_pids $image_codec $pids
	echo -en "\r"
	stop_timer convert_images_parallel
}

function encode_images()
{
	local image_codec=$RAW_IMAGE_CODEC
	if [ -z "$(list_contains $image_codec $MENCODER_IMAGE_CODECS)" ]
	then
		echo -e "\n$image_codec is not supported by mencoder - conversion to $DEFAULT_INTERMEDIATE_IMAGE_CODEC required"
		image_codec=$DEFAULT_INTERMEDIATE_IMAGE_CODEC
		convert_images $image_codec
	else
		echo -e "\n$image_codec is supported by mencoder - no conversion required"
	fi
	print_message Encoding images to video
	cmd="mencoder mf://$tmp_dir/*.$image_codec -mf fps=${opt_fps}:type=$image_codec"
	cmd="$cmd -fps ${opt_fps}"
	cmd="$cmd $(mencoder_options)"
	start_timer encode_images
	execute $cmd
	stop_timer encode_images
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Fix up some constants
test "$CONVERT_PARALLEL" == "no" && IMAGEMAGICK_MAX_PROCESSES=1
test "$IMAGEMAGICK_MAX_PROCESSES" -gt "1" && IMAGEMAGICK_MAX_THREADS=1

args=
for arg in "$@"
do
	args="$args \"$arg\""
done
parse_command_line $args

check_output

codec_type=$(get_codec_type $opt_codec)
container=$(get_value $opt_codec $CONTAINERS)

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

print_banner Starting execution

start_timer overall

# Make temporary directory
print_message "Creating temporary directory"
test ! -e $opt_tmp_dir && mkdir -p $opt_tmp_dir
export TMPDIR=$opt_tmp_dir
tmp_dir=`mktemp -d`
echo $tmp_dir
execute cd $tmp_dir

case $opt_source in
	screen)
		capture_screen
		;;
	camera)
		capture_camera
		;;
esac

# Remove temporary files
if [ "$opt_debug" != "yes" ]
then
	print_message "Removing temporary directory"
    rm -rf $tmp_dir
fi

echo -e "\nExecution complete"
stop_timer overall

