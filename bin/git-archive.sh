#!/bin/bash

# git-archive

# Script for archiving build artefacts generated from source code stored in
# git repositories.  Artefact filenames are prefixed with the SHA1 of the
# HEAD revision in the repository, allowing tracability back to the original
# source code.

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='suffix dest'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no
option_subdir=

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
# First argument is an error code
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
	test "$option_verbosity" != silent && echo -e "$cmd"
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
git-archive script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    suffix                  Suffix for files to archive
    dest                    Destination path

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit
    -s, --subdir            Source subdirectory

EOF
}

function print_version()
{
	cat << EOF
git-archive script version $SCRIPT_VERSION
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
				option_help=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				option_verbosity=silent
				;;
			-v | -verbose | --verbose)
				option_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				option_dryrun=yes
				;;
			-V | -version | --version)
				option_version=yes
				;;

			-s | -subdir | --subdir)
				prev=option_subdir
				;;
			-s=* | -subdir=* | --subdir=*)
				option_subdir=$optarg
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
Subdirectory ............................ $option_subdir
EOF
}

function check_is_repo()
{
    local repo=$1
    if [ "$option_dry_run" != "yes" ]
    then
        test -d $repo || error "$repo not found"
        cd $repo
        test -d .git || error "$repo is not a git repo"
    fi
}

function get_source_repo_details()
{
    if [ "$option_dry_run" != "yes" ]
    then
        source_remote_url=`git config --get remote.origin.url`
        source_branch=`git symbolic-ref HEAD`
        source_branch=${source_branch#refs/heads/}
        source_sha=`git log --pretty=%h -1 -- $arg_source_subdir`
        echo
        echo "Remote URL .... $source_remote_url"
        echo "Branch ........ $source_branch"
        echo "SHA1 .......... $source_sha"
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

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution

source_repo=$PWD

test -d $arg_dest || error "Destination folder $arg_dest not found"

check_is_repo $source_repo
get_source_repo_details

echo
echo "Finding files named *.$arg_suffix ..."
if [ "$option_dry_run" != "yes" ]
then
	files=`find ./$option_subdir -iname *.$arg_suffix`
fi

echo -e "\nCopying files ..."
for source_file in $files
do
	filename=`echo $source_file | sed -e 's/.*\///g'`
	dest_file=$arg_dest/$source_sha-$filename
	execute cp $source_file $dest_file
done

