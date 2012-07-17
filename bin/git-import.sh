#!/bin/bash

# git-import

# This script is used for pulling parts of one git repo (the source) into
# another (the target).  The origin of the files is recorded in the target,
# both via commit messages and text files added to the repo.

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='source_repo source_subdir target_subdir'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

source_remote_url=
source_branch=
source_sha=

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
	echo -e "\nError: $*"
	if [ "$option_dryrun" != yes ]
	then
		exit $code
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
	test "$option_verbosity" != silent && echo -e "\n$cmd"
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
git-import script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    source_repo             Path to source repository
    source_subdir           Path within source repository, to subdirectory
    target_subdir           Path within target repository, to subdirectory

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

EOF
}

function print_version()
{
	cat << EOF
git-import script version $SCRIPT_VERSION
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

function check_repo_is_clean()
{
	local repo=$1
	if [ "$option_dry_run" != "yes" ]
	then
		cd $repo
		git diff --exit-code
		test "$?" == "0" || error "Working tree of $repo is dirty"
		test -z "`git ls-files --others`" || error "Working tree of $repo is dirty"
	fi
}

function get_source_repo_details()
{
	execute cd $arg_source_repo
	if [ "$option_dry_run" != "yes" ]
	then
		source_remote_url=`git config --get remote.origin.url`
		source_branch=`git symbolic-ref HEAD`
		source_branch=${source_branch#refs/heads/}
		source_sha=`git log --pretty=%H -1 -- $arg_source_subdir`
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

target_repo=`pwd`

source_path=$arg_source_repo/$arg_source_subdir
target_path=$target_repo/$arg_target_subdir

test -d $source_path || error "Source path $source_path not found"

check_is_repo $arg_source_repo
check_is_repo $target_repo
check_repo_is_clean $arg_source_repo
check_repo_is_clean $target_repo

get_source_repo_details

commit_msg="Added"
if [ -e $target_path ]
then
	old_source_remote_url=`head -n1 $target_path/.origin`
	old_source_branch=`tail -n+2 $target_path/.origin | head -n1`
	old_source_sha=`tail -n+3 $target_path/.origin | head -n1`
	echo "URL: [$old_source_remote_url] [$source_remote_url]"
	if [ "$source_remote_url" == "$old_source_remote_url" -a "$source_branch" == "$old_source_branch" -a "$source_sha" == "$old_source_sha" ]
	then
		echo "Nothing changed"
		exit 0
	else
		commit_msg="Updated"
		execute rm -rf $target_path
	fi
fi
execute cp -r $source_path $target_path

commit_msg="$commit_msg $arg_target_subdir"

if [ "$option_dry_run" != "yes" ]
then
cat > $target_path/.origin << EOF
$source_remote_url
$source_branch
$source_sha
$arg_source_subdir
EOF
fi

execute cd $target_repo
execute git add $arg_target_subdir/

if [ "$option_dry_run" != "yes" ]
then
git commit -F- << EOF
$commit_msg

Source remote URL: $source_remote_url
Source branch: $source_branch
Source SHA: $source_sha
Source subdirectory: $arg_source_subdir
EOF
fi

execute git log --stat -1

