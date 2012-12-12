#!/bin/bash

# setup script for metasystem
#
# This script copies files from metasystem into the current user's home
# directory.  It should be used when setting up a new machine or user account.

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1
ARGUMENTS=''

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_force=
option_help=
option_version=
option_verbosity=normal

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Other globals
#------------------------------------------------------------------------------

dryrun=

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
# First argument is an error code
function error()
{
	code=$1
	shift
	echo "Error $code: $*"
	if [ "$dryrun" != yes ]
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
	test "$option_verbosity" != silent && echo $cmd
	if [ "$dryrun" != yes ]
	then
		$cmd
		r=$?
		if [ "$r" != 0 ]
		then
			error $r Execution of '$cmd' failed
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
		echo
	fi
}

function print_usage()
{
	cat << EOF
setup script for metasystem

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -f, --force             Don't prompt for confirmation
    -h, --help, --usage     Display this help and exit
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

EOF
}

function print_version()
{
	cat << EOF
setup script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	for token
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
				warn Unrecognized option '$token' ignored
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
				test -z "$arg_used" && warn Additional argument '$token' ignored
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
Dry run ................................. $dryrun
Windows ................................. $windows

Metasystem source path.. ................ $METASYSTEM_CORE_ROOT
HOME .................................... $HOME
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

Files to be installed:
EOF
	for f in $INSTALL_FILES; do echo "    $f"; done
	cat << EOF

Files to be archived:
EOF
	for f in $ARCHIVE_FILES; do echo "    $f"; done
}

function checked_mkdir()
{
	local dir=$1
	if [ -e "$dir" ]
	then
		if [ -z "$option_force" ]
		then
			echo -n "'$dir' already exists: delete? [y|n] "
			if [ -z "$dryrun" ]
			then
				read ans
				test "$ans" != "y" && exit 0
			fi
		fi
		execute rm -rf $dir
	fi
	execute mkdir -p $dir
}

function create_archive_dir()
{
	print_banner Creating archive directory
	checked_mkdir $ARCHIVE_DIR
	checked_mkdir $ARCHIVE_DIR/home
	checked_mkdir $ARCHIVE_DIR/usr/bin
}

function archive_existing_files()
{
	print_banner Archiving existing files
	local file=
	for file in $INSTALL_FILES $ARCHIVE_FILES
	do
		src=$HOME/.$file
		dest=$ARCHIVE_DIR/home/$file
		destdir=$(dirname $dest)
		if [ -e $src ]
		then
			test ! -d $destdir && execute mkdir -p $destdir
			execute mv $src $dest
		fi
	done
}

function install_files()
{
	print_banner Installing files
	login_file=profile
	test $METASYSTEM_OS != "windows" && login_file=bashrc
	local cmd="$METASYSTEM_CORE_BIN/subst-vars.sh \
		$METASYSTEM_SETUP/files/home/$login_file $HOME/.$login_file"
	execute $cmd
	if [ "$METASYSTEM_OS" == "linux" ]
	then
		execute mkdir -p ~/.config/autostart
		execute cp $METASYSTEM_SETUP/files/home/gnome-terminal.desktop ~/.config/autostart
	fi
}

function install_rc_files()
{
	print_banner Installing rc files
	for file in $INSTALL_FILES
	do
		src=$METASYSTEM_CORE_TEMPLATES/home/$file
		dest=$HOME/.$file
		destdir=$(dirname $dest)
		test ! -d $destdir && execute mkdir -p $destdir
		execute $METASYSTEM_CORE_BIN/subst-vars.sh $src $dest
	done
}

function setup_windows()
{
	cygwrapper_dir=
	test $METASYSTEM_PLATFORM == "cygwin" && cygwrapper_dir=/cygdrive/c/Apps/bin
	test $METASYSTEM_PLATFORM == "mingw" && cygwrapper_dir=/c/Apps/bin
	test ! -e $cygwrapper_dir && execute mkdir $cygwrapper_dir
	execute rm -f $cygwrapper_dir/cygwrapper.bat
	execute cp $METASYSTEM_CORE_BIN/cygwrapper.bat $cygwrapper_dir/cygwrapper.bat
}


function setup_cygwin()
{
	print_banner Cygwin-specific setup
	files='perl python'
	for file in $files
	do
		execute mv /usr/bin/$file $ARCHIVE_DIR/usr/bin/$file
		execute cp $METASYSTEM_CORE_BIN/cyg$file /usr/bin/$file
	done
	setup_windows
}

function setup_mingw()
{
	print_banner MinGW-specific setup
	for file in `'ls' $METASYSTEM_SETUP/files/msys/bin`
	do
		execute cp $METASYSTEM_SETUP/files/msys/bin/$file /bin/$file
	done
	setup_windows
}


function setup_todo()
{
	print_banner Setting up todo.sh
	execute mkdir $HOME/.todo
	execute ln -s $METASYSTEM_CORE_CONFIG/todo.cfg $HOME/.todo/config
	execute mkdir $HOME/.todo.actions.d
	todo_cmds='edit sync'
	for cmd in $todo_cmds
	do
		execute ln -s $METASYSTEM_CORE_BIN/todo-$cmd.sh $HOME/.todo.actions.d/$cmd
	done
}

function setup_generate_dot_files()
{
	print_banner Generating .metasystem-xxx files
	METASYSTEM_HOSTNAME=$HOSTNAME \
	METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config \
		execute $METASYSTEM_CORE_BIN/metasystem-profile.py set --reset --auto all
	METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config \
		execute $METASYSTEM_CORE_BIN/metasystem-id.py generate
	METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config \
		execute $METASYSTEM_CORE_BIN/metasystem-tools.py generate
}

function do_it()
{
	create_archive_dir
	archive_existing_files
	install_files
	install_rc_files
	test $METASYSTEM_PLATFORM == "cygwin" && setup_cygwin
	test $METASYSTEM_PLATFORM == "mingw" && setup_mingw
	setup_generate_dot_files
	#setup_todo
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line $*

if [ ! -z `uname | grep -i ^cygwin` ]
then
    METASYSTEM_OS=windows
    METASYSTEM_PLATFORM=cygwin
fi

if [ ! -z `uname | grep -i ^mingw` ]
then
    METASYSTEM_OS=windows
    METASYSTEM_PLATFORM=mingw
fi

if [ ! -z `uname | grep -i ^darwin` ]
then
    METASYSTEM_OS=mac
    METASYSTEM_PLATFORM=unix
fi

if [ -z "$METASYSTEM_PLATFORM" ]
then
    METASYSTEM_OS=linux
    METASYSTEM_PLATFORM=unix
fi

# Ensure these are exported, as tools in $METASYSTEM_CORE_BIN may rely on them
export METASYSTEM_OS
export METASYSTEM_PLATFORM

export METASYSTEM_CORE_ROOT=`cd $(dirname $0)/.. && echo $PWD`
export METASYSTEM_CORE_BIN=$METASYSTEM_CORE_ROOT/bin
export METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_ROOT/config
export METASYSTEM_CORE_SHELL=$METASYSTEM_CORE_ROOT/home
export METASYSTEM_CORE_LIB=$METASYSTEM_CORE_ROOT/lib
export METASYSTEM_CORE_TEMPLATES=$METASYSTEM_CORE_ROOT/templates
export METASYSTEM_SETUP=$METASYSTEM_CORE_ROOT/setup

INSTALL_FILES=$(cd $METASYSTEM_CORE_ROOT/templates/home && find . -type f | sed -e 's/\.\///g')
ARCHIVE_FILES='bashrc bash_profile profile todo todo.actions.d'

ARCHIVE_DIR=$HOME/metasystem-setup-archive

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

thick_rule='======================================================================'

echo -e "\n\n$thick_rule\nDry run\n$thick_rule"
dryrun=yes
do_it

echo -en "\nProceed? [y|n] "
read ans
test "$ans" != "y" && exit 0

echo -e "\n\n$thick_rule\nReal deal\n$thick_rule"
dryrun=
do_it

print_banner Execution complete

