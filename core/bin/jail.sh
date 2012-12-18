#!/bin/bash

# jail

# Script for preparing and entering a chroot jail

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

SCRIPT_DIR=$(dirname $(readlink -f $0))
[[ -z $METASYSTEM_CORE_LIB ]] && export METASYSTEM_CORE_LIB=$SCRIPT_DIR/../lib
source $METASYSTEM_CORE_LIB/sh/utils.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='action path'

VALID_ACTIONS='create remove enter'
NONROOT_USER=

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no

for arg in $ARGUMENTS; do eval "arg_$arg="; done

extra_args=

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
	test "$opt_verbosity" != silent && echo -e "$cmd"
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
jail script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    action                  ${VALID_ACTIONS// /|}

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
jail script version $SCRIPT_VERSION
EOF
}

function append_extra_arg()
{
    local arg=$1
    test -n "$extra_args" && extra_args="$extra_args "
    extra_args="$extra_args$arg"
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

			# Environment variables
			*=*)
				envvar=`expr "x$token" : 'x\([^=]*\)='`
				optarg=`echo "$optarg" | sed "s/'/'\\\\\\\\''/g"`
				eval "$envvar='$optarg'"
				export $envvar
				;;

			# Unrecognized options
			-*)
				append_extra_arg $token
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
				test -z "$arg_used" && append_extra_arg $token
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

	# Validate
    test -z $(list_contains $arg_action $VALID_ACTIONS) &&\
        usage_error "Invalid action"
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

Non-root user ........................... $NONROOT_USER

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

#------------------------------------------------------------------------------
# Actions
#------------------------------------------------------------------------------

function copy_deps()
{
	local exe=$arg_path/$1
	echo $exe
	ldout=$(ldd $exe)
	if [ "$?" == "0" ]
	then
		for lib in $ldout
		do
			if [ -e $lib ]
			then
				libdir=$(dirname $lib)
				libname=$(basename $lib)
				libdestdir=$root$libdir
				test -d $libdestdir ||\
					error "$lib: directory $libdestdir not found"
				destlib=$libdestdir/$libname
				echo -n "    $lib"
				if [ -e "$destlib" ]
				then
					echo " (already copied)"
				else
					echo
					test "$opt_dryrun" != "yes" && cp $lib $destlib
				fi
			fi
		done
	else
		echo "    Binary is not dynamic"
	fi
}

function copy_bin()
{
	echo -e "\nCopying binaries ..."
	local basic_binfiles='bash cat echo grep less ls mv pwd readlink rm rmdir sed sh which'
	local metasystem_binfiles='uname'
	local binfiles="$basic_binfiles $metasystem_binfiles"
	for x in $binfiles
	do
		execute cp /bin/$x $root/bin/$x
	done
}

function copy_usr()
{
	local root=$arg_path
	execute mkdir -p $root/usr/bin
	execute mkdir -p $root/usr/lib

	local usrbinfiles='ar as awk basename dirname env expr gcc g++ head ldd make tail time tr wc whoami'
	for x in $usrbinfiles
	do
		execute cp /usr/bin/$x $root/usr/bin/$x
	done
	local sbinfiles='ifconfig'
	for x in $sbinfiles
	do
		execute cp /sbin/$x $root/sbin/$x
	done

	# Copy gcc
	echo -e "\nCopying gcc"
	execute cp -r /usr/lib/gcc $root/usr/lib/gcc
	for file in $(find /usr/lib/gcc -type f)
	do
		copy_deps $file
	done

	# Copy headers
	echo -e "\nCopying headers"
	execute cp -r /usr/include $root/usr/include
}

function copy_lib()
{
	local root=$arg_path
	echo -e "\nCopying libraries ..."
	local bindirs='bin usr/bin'
	for dir in $bindirs
	do
		for file in $(ls $root/$dir)
		do
			copy_deps $dir/$file
		done
	done
}

function action_create()
{
	local root=$arg_path
	print_banner Creating jail $root
	test -d $root && error "Path $root already exists"

	# Create filesystem
	echo -e "\nCreating filesystem ..."
	local rootdirs='bin dev home lib lib64 proc sbin sys usr tmp'
	for x in $rootdirs
	do
		execute mkdir -p $root/$x
	done

	#copy_bin
	#copy_usr
	#copy_lib

	# Change ownership
	echo -e "\nChanging ownership ..."
	execute chown -R $NONROOT_USER $root

	# Mount directories
	echo -e "\nMounting directories ..."
	execute mount -o bind /dev $root/dev
	execute mount -t proc /proc $root/proc
	execute mount -t sysfs /sys $root/sys
	execute mount --bind /usr $root/usr
	execute mount --bind /lib $root/lib
	execute mount --bind /lib64 $root/lib64
	execute mount --bind /bin $root/bin
	execute mkdir -p $root/home/$NONROOT_USER
	execute mount --bind /home/$NONROOT_USER $root/home/$NONROOT_USER
}

function action_remove()
{
	local root=$arg_path
	print_banner Removing jail $root

	# Unmounting directories
	echo -e "\nUnounting directories ..."
	execute umount $root/home/$NONROOT_USER
	execute umount $root/bin
	execute umount $root/lib64
	execute umount $root/lib
	execute umount $root/usr
	execute umount $root/sys
	execute umount $root/proc
	execute umount $root/dev

	if [ -z $(ls $root/home/$NONROOT_USER) ]
	then
		echo -e "\nNow execute 'rm -rf $root' as non-root user"
	else
		error "Home directory not unmounted"
	fi
}

function action_enter()
{
	print_banner Entering jail $arg_path
	local shell=/bin/bash
	execute chroot --userspec=$(id -u $NONROOT_USER):$(id -g $NONROOT_USER) $arg_path $shell
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

NONROOT_USER=$(logname)

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

assert_superuser

eval action_${arg_action//-/_}

