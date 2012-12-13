#!/bin/bash

# qt-init-repo

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_QT_LIB/functions.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

DEFAULT_MODULES='
qtbase
qtdeclarative
qtjsbackend
qtmultimedia
qtrepotools
qtxmlpatterns'

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_force=no
option_help=
option_version=
option_verbosity=normal
option_dryrun=no

option_include_modules=
option_exclude_modules=

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
qt-init-repo script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:

Options:
    -f, --force             Force
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

	-i, --include MODULE    Include a module
	-e, --exclude MODULE    Exclude a module

EOF
}

function print_version()
{
	cat << EOF
qt-init-repo script version $SCRIPT_VERSION
EOF
}

function list_append()
{
	local element=$1
	shift
	local list="$*"
	test -n "$list" && element=" $element"
	echo $list$element
}

function list_remove()
{
	local element=$1
    shift
    local list="$*"
    echo $list | sed -e 's/ /\n/g' | grep -v "$element" | tr '\n' ' ' | sed 's/ $//'
}

function list_contains()
{
	local element=$1
	shift
	local list="$*"
	local result=
	for x in $list
	do
		test "$x" == "$element" && result=1
	done
	echo $result
}

function parse_command_line()
{
	eval set -- $*
	for token in "$@"
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"; then
			local p=$prev
			prev=
			if [ "$p" == "option_include_modules" ]
			then
				option_include_modules=$(list_append $token $option_include_modules)
				continue
			fi
			if [ "$p" == "option_exclude_modules" ]
			then
				option_exclude_modules=$(list_append $token $option_exclude_modules)
				prev=
				continue
			fi
			eval "$p=\$token"
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-f | -force | --force)
				option_force=yes
				;;
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

			-i | -include | --include)
				prev=option_include_modules
				;;
			-i=* | -include=* | --include=*)
				option_include_modules=$(list_append $optarg $option_include_modules)
				;;

			-e | -exclude | --exclude)
				prev=option_exclude_modules
				;;
			-e=* | -exclude=* | --exclude=*)
				option_exclude_modules=$(list_append $optarg $option_exclude_modules)
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

Force ................................... $option_force
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

function get_available_modules()
{
	test ! -e $QT_SOURCE_DIR/.gitmodules && error "\$QT_SOURCE_DIR/.gitmodules not found"
	available_modules=`cat .gitmodules | grep submodule | sed -e 's/.*"\(.*\)".*/\1/' | sort`
}

function print_available_modules()
{
	echo -e "\nAvailable modules:"
	echo $available_modules | sed -e 's/ /\n/g'
}

function check_module_available()
{
	local module=$1
	if [ -z $(list_contains $module $available_modules) ]
	then
		print_available_modules
		error "Module $module not available"
	fi
}

function check_include_exclude_lists()
{
	for module in $option_include_modules; do check_module_available $module; done
	for module in $option_exclude_modules; do check_module_available $module; done
}

function build_module_list()
{
	module_list=$DEFAULT_MODULES
	for module in $option_include_modules
	do
		module_list=$(list_append $module $module_list)
	done
	for module in $option_exclude_modules
	do
		module_list=$(list_remove $module $module_list)
	done
}

function print_module_list()
{
	echo -e "\nSelected modules:"
	for module in $available_modules
	do
		if [ -z $(list_contains $module $module_list) ]
		then
			echo "      $module"
		else
			echo "    "\* $module
		fi
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

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

print_banner Starting execution

check_pwd_in_qt_source_dir
get_available_modules
check_include_exclude_lists
build_module_list
print_module_list

print_banner Cloning Qt
echo
cmd="$QT_SOURCE_DIR/init-repository --module-subset=$(echo $module_list | sed -e 's/ /,/g')"
test "$option_force" == "yes" && cmd="$cmd --force"
execute $cmd

print_banner Installing hooks
commit_msg_src=$QT_SOURCE_DIR/.git/hooks/commit-msg
cmd="scp -p codereview.qt-project.org:hooks/commit-msg $commit_msg_src"
execute $cmd
echo
for module in $module_list
do
	commit_msg_dst=$QT_SOURCE_DIR/$module/.git/hooks/commit-msg
	execute rm -f $commit_msg_dst
	execute ln -s $commit_msg_src $commit_msg_dst
	if [ "$module" != "qtrepotools" ]
	then
		post_commit_src=$QT_SOURCE_DIR/qtrepotools/git-hooks/git_post_commit_hook
		post_commit_dst=$QT_SOURCE_DIR/$module/.git/hooks/post-commit
		execute rm -f $post_commit_dst
		if [ "$METASYSTEM_OS" == "windows" ]
		then
			execute cp $post_commit_src $post_commit_dst
		else
			execute ln -s $post_commit_src $post_commit_dst
		fi
	fi
done

