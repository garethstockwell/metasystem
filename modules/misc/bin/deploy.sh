#!/usr/bin/env bash

# deploy

# Script for zipping up and deploying files to a remote machine

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='local_path remote_host'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_clean=no
option_debug=no
option_dryrun=no
option_help=
option_remote_path=
option_remote_user=
option_version=
option_verbosity=normal
option_remote_tmp=/tmp

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
	echo -e "\nError: $*"
	if [ "$option_dryrun" != yes ]
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
	test "$option_verbosity" != silent && echo $cmd
	if [ "$option_dryrun" != yes ]
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
	test "$option_verbosity" != silent && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [ "$option_verbosity" != silent ]
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
deploy script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    local_path              Local source path
    remote_host             Hostname of remote machine

Options:
    -c, --clean             Remove existing remote directory if existing
    -d, --debug             Don't remove temporary files at end of run
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -u, --remote-user       Remote username
    -V, --version           Display version information and exit
    -r, --remote-path       Remote target path
    -t, --remote-tmp        Remote temporary directory

EOF
}

function print_version()
{
	cat << EOF
deploy script version $SCRIPT_VERSION
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
			-c | -clean | --clean)
				option_clean=yes
				;;
			-d | -debug | --debug)
			    option_debug=yes
				;;
			-h | -help | --help | -usage | --usage)
				option_help=yes
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				option_dryrun=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				option_verbosity=silent
				;;
			-r | -remote-path | --remote-path)
				prev=option_remote_path
				;;
			-r=* | -remote-path=* | --remote-path=*)
				option_remote_path=$optarg
				;;
			-t | -remote-tmp | --remote-tmp)
				prev=option_remote_tmp
				;;
			-t=* | -remote-tmp=* | --remote-tmp=*)
				option_remote_tmp=$optarg
				;;

			-u | -remote-user | --remote-user)
				prev=option_remote_user
				;;
			-u=* | -remote-user=* | --remote-user=*)
				option_remote_user=$optarg
				;;
			-v | -verbose | --verbose)
				option_verbosity=verbose
				;;
			-V | -version | --version)
				option_version=yes
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

	if [ -z "$option_remote_path" ]
	then
		echo "No remote path supplied - using local path ($arg_local_path)"
		option_remote_path=$arg_local_path
	fi
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Clean ................................... $option_clean
Debug ................................... $option_debug
Verbosity ............................... $option_verbosity
Dry run ................................. $option_dryrun

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

cat << EOF

Remote path ............................. $option_remote_path
Remote user ............................. $option_remote_user
Remote temporary path ................... $option_remote_tmp

EOF
}

function copy_to_remote()
{
	local src=$1
	local dest=$2
	remote_scp="$arg_remote_host:$dest"
	test -n "$option_remote_user" && remote_scp="$option_remote_user@$remote_scp"
	cmd="scp $src $remote_scp"
	execute $cmd
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

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution

# Check source path exists
echo -e "\nChecking source path ..."
test -d "$arg_local_path" || error "Source path $arg_local_path not found"
abs_local_path=`cd $arg_local_path && pwd`
echo "Absolute local directory = $abs_local_path"

# Create regex for stripping source path from source files
abs_local_path_regex=`echo $abs_local_path | sed -e 's/\//\\\\\//g'`
echo regex=$abs_local_path_regex
strip_path_regex="s/^$abs_local_path_regex//g"

# Make temporary local directory
echo -en "\nCreating temporary local directory ... "
local_tmp_dir=`mktemp -d`
tmp_leaf=`echo $local_tmp_dir | sed -e 's/.*\///g'`
echo "$local_tmp_dir ($tmp_leaf)"

# Create local archive
echo -e "\nCreating local archive ..."
local_archive=$local_tmp_dir/archive.tar.bz2
cmd="tar -cjf $local_archive $arg_local_path --absolute-names --transform $strip_path_regex"
test "$option_verbosity" == "verbose" && cmd="$cmd -v"
execute $cmd

# Compose remote paths
remote_archive=$option_remote_tmp/${tmp_leaf}_archive.tar.bz2
remote_script=$option_remote_tmp/${tmp_leaf}_unpack.sh

# Create local shell script
echo -e "\nCreating local shell script ..."
local_script=$local_tmp_dir/unpack.sh
echo "#!/bin/sh" >> $local_script
test "$option_clean" == "yes" && \
	echo "rm -rf $option_remote_path" >> $local_script
echo "test ! -d $option_remote_path && mkdir -p $option_remote_path" >> $local_script
cmd="tar xjf $remote_archive -C $option_remote_path --no-same-owner"
test "$option_verbosity" == "verbose" && cmd="$cmd -v"
echo $cmd >> $local_script

# Copy files to remote machine
echo -e "\nCopying files to remote machine ..."
copy_to_remote $local_archive $remote_archive
copy_to_remote $local_script $remote_script

# Execute remote shell script
echo -e "\nExecuting remote shell script ..."
remote_host=$arg_remote_host
test -n "$option_remote_user" && \
	remote_host="$option_remote_user@$remote_host"
cmd="ssh $remote_host sh $remote_script"
execute $cmd

# Remove temporary files
if [ "$option_debug" != "yes" ]
then
	echo -e "\nRemoving temporary local directory ..."
	rm -rf $local_tmp_dir
	echo -e "\nRemoving temporary remote files ..."
	cmd="ssh $remote_host rm -rf $remote_archive"
	execute $cmd
	cmd="ssh $remote_host rm -rf $remote_script"
	execute $cmd
fi

