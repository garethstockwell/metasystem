#!/bin/bash

# ubuntu-install-ffmpeg
# See https://ffmpeg.org/trac/ffmpeg/wiki/UbuntuCompilationGuide

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/build.sh
source $METASYSTEM_CORE_LIB_BASH/misc.sh
source $METASYSTEM_CORE_LIB_BASH/script.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

SOURCE_ROOT=$HOME/work/local/packages


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

for arg in $ARGUMENTS; do
	eval "arg_$arg="
done

opt_clean=no
opt_numjobs=$(number_of_processors)


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
ubuntu-install-ffmpeg script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    source                  Source path
    dest                    Destination path

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    -c, --clean             Remove and re-install packages

    -j JOBS                 Number of build jobs

EOF
}

function print_version()
{
	cat << EOF
ubuntu-install-ffmpeg script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $*
	parse_standard_arguments "$@"

	for token in $unused_args; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			-j*)
				opt_numjobs=${token/-j/}
				;;
			-j)
				prev=opt_numjobs
				;;

			-c | -clean | --clean)
				opt_clean=yes
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
				for arg in $ARGUMENTS; do
					if [[ -z `eval "echo \\$arg_$arg"` ]]; then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				[[ -z "$arg_used" ]] && warn "Additional argument '$token' ignored"
				;;
		esac
	done

	local args_supplied=1
	for arg in $ARGUMENTS; do
		if [[ -z `eval "echo \\$arg_$arg"` ]]; then
			args_supplied=
			break
		fi
	done
	[[ -z "$args_supplied" ]] && usage_error 'Insufficient arguments provided'
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Clean ................................... $opt_clean
Jobs .................................... $opt_numjobs

EOF
	for arg in $ARGUMENTS; do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done
}


#------------------------------------------------------------------------------
# Guts
#------------------------------------------------------------------------------

function check_preconditions()
{
	[[ $METASYSTEM_OS_VENDOR != ubuntu ]] && error "Only for use on Ubuntu"

	# Trim version number
	oIFS="$IFS"
	IFS=.
	set -- $METASYSTEM_OS_VERSION
	export METASYSTEM_OS_VERSION=$1.$2
	IFS="$oIFS"
	[[ $METASYSTEM_OS_VERSION != 12.04 ]] && error "Only for use on Ubuntu 12.04"

	assert_superuser
}

function install_dependencies()
{
	print_banner Installing dependencies

	# Remove unwanted packages
	execute_warn apt-get remove -y libav-tools

	# Remove stuff this script will install
	if [[ $opt_clean == yes ]]; then
		execute_warn apt-get remove -y ffmpeg x264 libvpx-dev libx264-dev yasm
	fi

	# Install dependencies
	execute apt-get update
	execute apt-get -y install autoconf automake build-essential checkinstall git \
		libass-dev libfaac-dev libgpac-dev libjack-jackd2-dev libmp3lame-dev \
		libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev libsdl1.2-dev \
		libspeex-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev \
		libx11-dev libxext-dev libxfixes-dev pkg-config texi2html zlib1g-dev
}

function init_package()
{
	package=$1
	version=$2
	source_dir=$package
	[[ -n $version ]] && source_dir=$source_dir-$version

	print_banner $package $version

	execute cd $SOURCE_ROOT

	if [[ -d $source_dir ]]; then
		if [[ $opt_clean == yes ]]; then
			echo "Removing old source directory"
			execute rm -rf $source_dir
		else
			echo "Source directory already exists - skipping"
			return 1
		fi
	fi

	if [[ $opt_clean == yes ]]; then
		echo "Removing package $package"
		execute_warn apt-get autoremove -y $package
	fi
}

function install_yasm()
{
	init_package yasm 1.2.0

	if [[ ! -d $source_dir ]]; then
		execute wget http://www.tortall.net/projects/yasm/releases/$package-$version.tar.gz
		execute tar xzvf $package-$version.tar.gz
		execute cd $source_dir
		execute ./configure
		execute $make_cmd
		execute checkinstall --pkgname=$package --pkgversion="$version" \
			--backup=no --deldoc=yes --fstrans=no --default
	fi
}

function install_x264()
{
	init_package x264

	if [[ ! -d $source_dir ]]; then
		execute git clone --depth 1 git://git.videolan.org/x264.git $source_dir
		execute cd $source_dir
		execute ./configure --enable-static
		execute $make_cmd
		execute checkinstall --pkgname=$package --pkgversion="3:$(./version.sh | \
			awk -F'[" ]' '/POINT/{print $4"+git"$5}')" --backup=no --deldoc=yes \
			--fstrans=no --default
	fi
}

function install_fdk_aac()
{
	init_package fdk-aac

	if [[ ! -d $source_dir ]]; then
		execute git clone --depth 1 git://github.com/mstorsjo/fdk-aac.git $source_dir
		execute cd $source_dir
		execute autoreconf -fiv
		execute ./configure --disable-shared
		execute $make_cmd
		execute checkinstall --pkgname=$package --pkgversion="$(date +%Y%m%d%H%M)-git" \
			--backup=no --deldoc=yes --fstrans=no --default
	fi
}

function install_libvpx()
{
	init_package libvpx

	if [[ ! -d $source_dir ]]; then
		execute git clone --depth 1 http://git.chromium.org/webm/libvpx.git $source_dir
		execute cd $source_dir
		execute ./configure --disable-examples --disable-unit-tests
		execute $make_cmd
		execute checkinstall --pkgname=$package --pkgversion="1:$(date +%Y%m%d%H%M)-git" \
			--backup=no --deldoc=yes --fstrans=no --default
	fi
}

function install_ffmpeg()
{
	init_package ffmpeg

	if [[ ! -d $source_dir ]]; then
		execute git clone --depth 1 git://source.ffmpeg.org/ffmpeg $source_dir
		execute cd $source_dir
		execute ./configure --enable-gpl --enable-libass --enable-libfaac \
			--enable-libfdk-aac --enable-libmp3lame --enable-libopencore-amrnb \
			--enable-libopencore-amrwb --enable-libspeex --enable-librtmp \
			--enable-libtheora --enable-libvorbis --enable-libvpx \
			--enable-x11grab --enable-libx264 --enable-nonfree --enable-version3
		execute $make_cmd
		execute checkinstall --pkgname=ffmpeg --pkgversion="7:$(date +%Y%m%d%H%M)-git" \
			--backup=no --deldoc=yes --fstrans=no --default
		execute hash -r
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_command_line $args

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

check_preconditions

print_banner Starting execution

make_cmd="$(which make) -j $opt_numjobs"

[[ ! -d $SOURCE_ROOT ]] && execute mkdir -p $SOURCE_ROOT

install_dependencies

install_yasm
install_x264
install_fdk_aac
install_libvpx
install_ffmpeg

