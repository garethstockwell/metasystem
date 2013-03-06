#!/usr/bin/env bash

# wayland-build

# Script for cloning and building Wayland and its dependencies
# Based on http://wayland.freedesktop.org/building.html

# Note that the following environment variables should be set:
#
# export WAYLAND_PREFIX=...
# export LD_LIBRARY_PATH=$WAYLAND_PREFIX/lib
# export PKG_CONFIG_PATH=$WAYLAND_PREFIX/lib/pkgconfig:$WAYLAND_PREFIX/share/pkgconfig
# export ACLOCAL="aclocal -I $WAYLAND_PREFIX/share/aclocal"


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

SCRIPT_DIR=$(dirname $(readlink -f $0))
[[ -z $METASYSTEM_CORE_LIB ]] && export METASYSTEM_CORE_LIB=$SCRIPT_DIR/../lib
source $METASYSTEM_CORE_LIB_BASH/utils.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='root'

GIT_wayland=git://anongit.freedesktop.org/wayland/wayland
CONFIGURE_FLAGS_wayland='--enable-nouveau-experimental-api'

# mesa
PROJECTS_mesa='drm macros glproto dri2proto mesa'
GIT_drm=git://anongit.freedesktop.org/git/mesa/drm
GIT_macros=git://anongit.freedesktop.org/git/xorg/util/macros
GIT_glproto=git://anongit.freedesktop.org/xorg/proto/glproto
GIT_dri2proto=git://anongit.freedesktop.org/xorg/proto/dri2proto
GIT_mesa=git://anongit.freedesktop.org/mesa/mesa
CONFIGURE_FLAGS_drm=
CONFIGURE_FLAGS_macros=
CONFIGURE_FLAGS_glproto=
CONFIGURE_FLAGS_dri2proto=
CONFIGURE_FLAGS_mesa='--enable-gles2 --disable-gallium-egl
--with-egl-platforms=x11,wayland,drm --enable-gbm --enable-shared-glapi
--with-gallium-drivers=r300,r600,swrast,nouveau'

# libxcbcommon
PROJECTS_libxcbcommon='xproto kbproto libX11 libxcbcommon'
GIT_xproto=git://anongit.freedesktop.org/xorg/proto/xproto
GIT_kbproto=git://anongit.freedesktop.org/xorg/proto/kbproto
GIT_libX11=git://anongit.freedesktop.org/xorg/lib/libX11
GIT_libxcbcommon=git://anongit.freedesktop.org/xorg/lib/libxcbcommon.git
CONFIGURE_FLAGS_xproto=
CONFIGURE_FLAGS_kbproto=
CONFIGURE_FLAGS_libX11=
CONFIGURE_FLAGS_libxcbcommon=--with-xkb-config-root=/usr/share/X11/xkb

# weston
GIT_weston=git://anongit.freedesktop.org/wayland/weston
CONFIGURE_FLAGS_weston=

PROJECTS="wayland $PROJECTS_mesa $PROJECTS_libxcbcommon weston"

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_force=
opt_version=
opt_verbosity=normal
opt_dryrun=no

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Utility functions
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

# Execute shell command; abort script if command fails
function execute()
{
	cmd="$*"
	test "$opt_verbosity" != silent && echo -e "$cmd"
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

function print_usage()
{
	cat << EOF
wayland-build script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -f, --force             Force
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

EOF
}

function print_version()
{
	cat << EOF
wayland-build script version $SCRIPT_VERSION
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
			-h | -help | --help | -usage | --usage)
				opt_help=yes
				;;
			-f | -force | --force)
				opt_force=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				opt_verbosity=silent
				;;
			-v | -verbose | --verbose)
				opt_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				opt_dryrun=yes
				;;
			-V | -version | --version)
				opt_version=yes
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
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun
Force ................................... $opt_force

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
# The guts
#------------------------------------------------------------------------------

function create_install_dir()
{
	print_banner Creating installation directory
	local create=yes
	if [ -e "$WAYLAND_PREFIX" ]
	then
		if [ -n "$opt_force" ]
		then
			execute rm -rf $WAYLAND_PREFIX
		else
			echo "$WAYLAND_PREFIX already exists - use --force to recreate"
			create=no
		fi
	fi
	test $create == 'yes' && execute mkdir -p $WAYLAND_PREFIX
}

function clone_project()
{
	local project=$1
	print_banner Cloning $project
	local clone=yes
	local dir=$arg_root/source/$project
	if [ -e "$dir" ]
	then
		if [ -n "$opt_force" ]
		then
			execute rm -rf $dir
		else
			echo "Directory $dir already exists - use --force to recreate"
			clone=no
		fi
	fi
	if [ $clone == 'yes' ]
	then
		test ! -e $(dirname $dir) && execute mkdir -p $(dirname $dir)
		eval "local repo=\$GIT_$project"
		execute git clone $repo $dir
	fi
}

function clone_projects()
{
	for project in $PROJECTS
	do
		clone_project $project
	done
}

function build_project()
{
	local project=$1
	print_banner Building $project
	local dir=$arg_root/source/project
	eval "local configure_flags=\$CONFIGURE_FLAGS_$project"
	configure_flags="--prefix=$WAYLAND_PREFIX $configure_flags"
	execute cd $dir
	execute ./autogen.sh $configure_flags
	execute make -j $(number_of_processors)
	execute make install
}

function build_projects()
{
	for project in $PROJECTS
	do
		build_project $project
	done
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"
do
	args="$args \"$arg\""
done
parse_command_line $args

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

print_banner Starting execution

test -z "$WAYLAND_PREFIX" && error "WAYLAND_PREFIX not set"
test ! -e "$WAYLAND_PREFIX" && error "WAYLAND_PREFIX $WAYLAND_PREFIX not found"

create_install_dir
clone_projects
build_projects

