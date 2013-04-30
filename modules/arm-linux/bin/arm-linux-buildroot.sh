#!/bin/bash

# arm-linux-buildroot

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

DEFAULT_BUILDROOT_VERSION=2013.02
BUILDROOT_URL_ROOT=http://buildroot.uclibc.org/downloads


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

arg_action=
arg_extra=

opt_force=no
opt_buildroot_version=


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
			-buildroot-version | --buildroot-version)
				prev=opt_buildroot_version
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

	[[ -z $opt_buildroot_version ]] && opt_buildroot_version=$DEFAULT_BUILDROOT_VERSION
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
}

function action_configure()
{
	print_banner "Configuring buildroot"
	check_does_exist ${BUILDROOT_FOLDER}
	execute cd ${BUILDROOT_FOLDER}
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

BUILDROOT_FOLDER=buildroot-${opt_buildroot_version}
BUILDROOT_TARBALL=${BUILDROOT_FOLDER}.tar.bz2

eval action_${arg_action//-/_}

