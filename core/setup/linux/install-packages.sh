#!/usr/bin/env bash

# install-packages

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

SCRIPT_DIR=$(dirname $(readlink -f $0))
source $METASYSTEM_CORE_LIB_BASH/utils.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='list'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_yes=no

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Functions
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
	test "$opt_verbosity" != silent && echo -e "\n$cmd"
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
install-packages script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    list                    Name of package list to install

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit
    -y, --yes               Do not prompt

EOF
}

function print_version()
{
	cat << EOF
install-packages script version $SCRIPT_VERSION
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
			-y | -yes | --yes)
				opt_yes=yes
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

Distro .................................. $METASYSTEM_OS_VENDOR
Distro version .......................... $METASYSTEM_OS_VERSION

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun
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

PKG_LISTS_PROCESSED=''

function process_file()
{
	local filename=$1
	if [ -z "`echo $PKG_LISTS_PROCESSED | grep -i $filename`" ]
	then
		PKG_LISTS_PROCESSED="$PKG_LISTS_PROCESSED $filename"
		echo "Parsing $filename ..."
		local common_filename=$PKG_LIST_DIR/$filename
		while read line
		do
			line=`echo $line | sed -e 's/#.*//g' | sed 's/^[ \t]*//;s/[ \t]*$//'`
			if [ ! -z "$line" ]
			then
				if [ ! -z "`echo $line | grep -i '^include '`" ]
				then
					include=`echo $line | sed -e 's/^include[ ]*//'`
					process_file $include
				else
					test -n "$PKG_LIST" && PKG_LIST="$PKG_LIST "
					PKG_LIST="$PKG_LIST $line"
				fi
			fi
		done < $common_filename
		if [ -n "$linux_distro_version" ]
		then
			local distro_filename=$linux_distro_version/$filename
			if [ -e $PKG_LIST_DIR/$distro_filename ]
			then
				process_file $distro_filename
			fi
		fi
	fi
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

# sudo discards METASYSTEM_OS* variables, so recreate them here
check_os

### HACK ###
METASYSTEM_OS_VERSION=12.04

assert_is_linux
linux_distro_version=${METASYSTEM_OS_VENDOR}-${METASYSTEM_OS_VERSION}

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

assert_superuser

print_banner Parsing package lists
PKG_LIST_DIR=`dirname $0`/packages
PKG_LIST=''
process_file $arg_list
PKG_LIST=$(echo $PKG_LIST | sed -e 's/ /\n/g' | sort -u)

print_banner Package list
echo $PKG_LIST | sed -e 's/ /\n/g'

yes=
test "$opt_yes" == "yes" && yes=-y
execute aptitude $yes install $PKG_LIST

