#!/bin/bash

# arm-linux-kernel

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/list.sh
source $METASYSTEM_CORE_LIB_BASH/script.sh


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1
VALID_ACTIONS='download unzip configure'

DEFAULT_KERNEL_VERSION=3.8.10
KERNEL_URL_ROOT=https://www.kernel.org/pub/linux/kernel/v3.x/


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

arg_action=
arg_extra=

opt_force=no
opt_kernel_version=


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
			-kernel-version | --kernel-version)
				prev=opt_kernel_version
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

	[[ -z $opt_kernel_version ]] && opt_kernel_version=$DEFAULT_KERNEL_VERSION
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

function check_does_exist()
{
	local path=$1
	if [[ $opt_dryrun != yes && ! -e $path ]]; then
		error "Path $path does not exist"
	fi
}

function check_does_not_exist()
{
	local path=$1
	local r=0
	if [[ $opt_dryrun != yes ]]; then
		if [[ -e $path ]]; then
			if [[ $opt_force != yes ]]; then
				ask "Path $path exists - remove?" || r=1
			fi
			[[ $r = 0 ]] && execute rm -rf $path
		fi
	fi
	return $r
}


#------------------------------------------------------------------------------
# Guts
#------------------------------------------------------------------------------

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

parse_command_line $args

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

KERNEL_FOLDER=linux-${opt_kernel_version}
KERNEL_TARBALL=${KERNEL_FOLDER}.tar.xz

eval action_${arg_action//-/_}
