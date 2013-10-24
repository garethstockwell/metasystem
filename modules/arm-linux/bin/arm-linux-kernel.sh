#!/bin/bash

# arm-linux-kernel

# Helper script for downloading and compiling Linux kernel

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
VALID_ACTIONS='clone download unzip configure'

DEFAULT_KERNEL_VERSION=3.8.10
KERNEL_URL_ROOT=https://www.kernel.org/pub/linux/kernel/v3.x/
KERNEL_REPO_URL=git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

arg_action=
arg_extra=

opt_force=no
opt_kernel_version=
opt_tag=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
arm-linux-kernel script

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
    --kernel-version VER    Specify kernel version (default $DEFAULT_KERNEL_VERSION)

Options for clone:

EOF
}

function print_version()
{
	cat << EOF
arm-linux-kernel script version $SCRIPT_VERSION
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
			-kernel-version | --kernel-version)
				prev=opt_kernel_version
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
	[[ -z $opt_kernel_version ]] && opt_kernel_version=$DEFAULT_KERNEL_VERSION

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

Kernel version .......................... $opt_kernel_version

ARCH .................................... $ARCH
SUBARCH ................................. $SUBARCH
CROSS_COMPILE ........................... $CROSS_COMPILE

EOF
}


#------------------------------------------------------------------------------
# Guts
#------------------------------------------------------------------------------

function action_clone()
{
	print_banner "Cloning kernel"
	check_does_not_exist ${KERNEL_FOLDER}
	execute git clone ${KERNEL_REPO_URL} ${KERNEL_FOLDER}
	if [[ -n $opt_tag ]]; then
		execute cd ${KERNEL_FOLDER}
		execute git checkout ${opt_tag} -b ${opt_tag}
	fi
}

function action_download()
{
	print_banner "Downloading kernel"
	local kernel_url=${KERNEL_URL_ROOT}/${KERNEL_TARBALL}
	check_does_not_exist ${KERNEL_TARBALL}
	execute curl ${kernel_url} -o ${KERNEL_TARBALL}
}

function action_unzip()
{
	print_banner "Unzipping kernel"
	check_does_exist ${KERNEL_TARBALL}
	check_does_not_exist ${KERNEL_FOLDER}
	execute tar xvf ${KERNEL_TARBALL}
	if [[ $opt_dryrun != yes ]]; then
		echo ${opt_kernel_version} > ${KERNEL_FOLDER}/version.txt
	fi
}

function action_configure()
{
	print_banner "Configuring kernel"
	check_does_exist ${KERNEL_FOLDER}
	execute cd ${KERNEL_FOLDER}
	execute make versatile_defconfig
	echo "Now execute 'make menuconfig'"
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

KERNEL_FOLDER=linux
KERNEL_TARBALL=${KERNEL_FOLDER}.tar.xz

eval action_${arg_action//-/_}

