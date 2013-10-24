#!/bin/bash

# arm-linux-buildroot

# Helper script for downloading and compiling buildroot

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/list.sh
source $METASYSTEM_CORE_LIB_BASH/script.sh
source $METASYSTEM_ARM_LINUX_LIB_BASH/misc.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1
VALID_ACTIONS='clone download unzip configure sync'

DEFAULT_BUILDROOT_VERSION=2013.02
BUILDROOT_URL_ROOT=http://buildroot.uclibc.org/downloads
BUILDROOT_REPO_URL=git://git.busybox.net/buildroot


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

arg_action=
arg_extra=

opt_force=no
opt_clean=no
opt_buildroot_version=
opt_rootfs=
opt_tag=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
arm-linux-buildroot script

Usage: $0 [options] <action>

Default values for options are specified in brackets.

Valid actions: $VALID_ACTIONS

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    -f, --force             Remove old files / folders without prompting
    --buildroot-version VER Specify buildroot version (default $DEFAULT_BUILDROOT_VERSION)
    --rootfs ROOTFS         Specify rootfs
    --clean                 Clean rootfs

Options for clone:
    --tag TAG               Check out specified tag

EOF
}

function print_version()
{
	cat << EOF
arm-linux-buildroot script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $unused_args

	for token in "$@"; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			-buildroot-version | --buildroot-version)
				prev=opt_buildroot_version
				;;

			-rootfs | --rootfs)
				prev=opt_rootfs
				;;

			-clean | --clean)
				opt_clean=yes
				;;

			-tag | --tag)
				prev=opt_tag
				;;

			# Unrecognized options
			-*)
				warn "Unrecognized option '$token' ignored"
				;;

			# Normal arguments
			*)
				if [[ -z "$arg_action" ]]; then
					arg_action=$token
				else
					[[ -n "$arg_extra" ]] && arg_extra="$arg_extra "
					arg_extra=$arg_extra$token
				fi
				;;
		esac
	done

	[[ -z "$arg_action" ]] && usage_error "No action supplied"
	[[ -z $(list_contains $arg_action $VALID_ACTIONS) ]] &&\
		usage_error "Invalid action '$arg_action'"

	# Set defaults
	[[ -z $opt_buildroot_version ]] && opt_buildroot_version=$DEFAULT_BUILDROOT_VERSION
	[[ -z $opt_rootfs ]] && opt_rootfs=$ARM_LINUX_ROOTFS

	[[ $arg_action != clone && -n $opt_tag ]] &&\
		warn "Ignoring option -tag"
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Action .................................. $arg_action

Buildroot version ....................... $opt_buildroot_version
rootfs .................................. $opt_rootfs

EOF
}


#------------------------------------------------------------------------------
# Guts
#------------------------------------------------------------------------------

function action_download()
{
	print_banner "Downloading buildroot"
	local buildroot_url=${BUILDROOT_URL_ROOT}/${BUILDROOT_TARBALL}
	check_does_not_exist ${BUILDROOT_TARBALL}
	execute curl ${buildroot_url} -o ${BUILDROOT_TARBALL}
}

function action_unzip()
{
	print_banner "Unzipping buildroot"
	check_does_exist ${BUILDROOT_TARBALL}
	check_does_not_exist ${BUILDROOT_FOLDER}
	execute tar xjvf ${BUILDROOT_TARBALL}
	if [[ $opt_dryrun != yes ]]; then
		echo ${opt_buildroot_version} > ${BUILDROOT_FOLDER}/version.txt
	fi
}

function action_clone()
{
	print_banner "Cloning buildroot"
	check_does_not_exist ${BUILDROOT_FOLDER}
	execute git clone ${BUILDROOT_REPO_URL} ${BUILDROOT_FOLDER}
	if [[ -n $opt_tag ]]; then
		execute cd ${BUILDROOT_FOLDER}
		execute git checkout ${opt_tag} -b ${opt_tag}
	fi
}

function action_configure()
{
	print_banner "Configuring buildroot"
	check_does_exist ${BUILDROOT_FOLDER}
	execute cd ${BUILDROOT_FOLDER}
	execute make menuconfig
}

function action_sync()
{
	print_banner "Syncing rootfs"
	rootfs_tar=${BUILDROOT_FOLDER}/output/images/rootfs.tar
	check_does_exist ${BUILDROOT_FOLDER}
	check_does_exist ${rootfs_tar}
	[[ -z $opt_rootfs ]] && error "No rootfs specified"
	if [[ $opt_clean == yes ]]; then
		local remove=yes
		[[ $opt_dryrun != yes && $opt_force != yes ]] && ask "Remove existing rootfs?" || remove=no
		[[ $remove == yes ]] && execute sudo rm -rf $opt_rootfs
	fi
	if [[ -d $opt_rootfs ]]; then
		local tmp_rootfs=/tmp/rootfs
		execute sudo rm -rf $tmp_rootfs
		execute mkdir -p $tmp_rootfs
		execute sudo tar -C $tmp_rootfs -xf $rootfs_tar
		execute sudo rsync -av $tmp_rootfs/ $opt_rootfs
		execute sudo rm -rf $tmp_rootfs
	else
		execute mkdir -p $opt_rootfs
		execute sudo tar -C $opt_rootfs -xf $rootfs_tar
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_standard_args $args
parse_command_line

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

BUILDROOT_FOLDER=buildroot
BUILDROOT_TARBALL=${BUILDROOT_FOLDER}.tar.bz2

eval action_${arg_action//-/_}

