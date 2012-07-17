#!/bin/bash

# qt-harmattan

# Porcelain script for development of Qt targetting Harmattan
# Based on instructions from
# http://trac.webkit.org/wiki/SettingUpDevelopmentEnvironmentForN9

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

SCRIPT_DIR=$(dirname $(readlink -f $0))
[[ -z $METASYSTEM_LIB ]] && export METASYSTEM_LIB=$SCRIPT_DIR/../lib
source $METASYSTEM_LIB/bash/utils.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS='action'

VALID_ACTIONS='setup-env flash-device setup-device
jail-create jail-enter jail-remove
configure build clean deploy
qt-configure qt-build
mobility-configure mobility-build
'

# git://github.com/resworb/scripts.git
HELPER_SCRIPTS_DIR=$SCRIPT_DIR/../../resworb-scripts

IMAGE_DIR=~/work/sync/unison/live/projects/qt/harmattan
VARIANT_DIR=n9_20.2011.40.4_RM-696-NDT-NORTH-EUROPE-CYAN-16GB
IMAGE_ROOT=DFL61_HARMATTAN_20.2011.40-4_PR_LEGACY_001-OEM1-958_ARM.bin
IMAGE_EMMC=DFL61_HARMATTAN_20.2011.40-4.CENTRALEUROPE_EMMC_CENTRALEUROPE.bin
IMAGE_KERNEL=zImage-2.6.32.39-dfl61-20113701

DEFAULT_REMOTE_USER=user
DEFAULT_REMOTE_HOSTNAME=n9

REMOTE_USER=$QT_HARMATTAN_REMOTE_USER
REMOTE_HOSTNAME=$QT_HARMATTAN_REMOTE_HOSTNAME
PREFIX=$QT_HARMATTAN_PREFIX

TOOLS=
TOOLS_QT4='qmeegographicssystemhelper qml'


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no

opt_deploy_debug=no

extra_args=

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
	cmd=$@
	test "$opt_verbosity" != silent && echo $cmd
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
qt-harmattan script

Usage: $0 [options] <action> $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    action                  ${VALID_ACTIONS// /|}

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

Options for deploy:
    --debug                 Deploy debugging symbols
*   --no-debug              Do not deploy debugging symbols

EOF
}

function print_version()
{
	cat << EOF
qt-harmattan script version $SCRIPT_VERSION
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

			-debug | --debug)
				opt_deploy_debug=yes
				;;
			-no-debug | --no-debug)
				opt_deploy_debug=no
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

EOF

	test -n "$REMOTE_USER" && cat << EOF
Remote user ............................. $REMOTE_USER
Remote hostname ......................... $REMOTE_HOSTNAME
Remote prefix ........................... $PREFIX

EOF

	test -n "$qt_version" && cat << EOF
Qt source dir ........................... $QT_SOURCE_DIR
Qt build dir ............................ $QT_BUILD_DIR
Qt version .............................. $qt_version

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

function assert_helper_scripts_exist()
{
	test -d $HELPER_SCRIPTS_DIR || error "$HELPER_SCRIPTS_DIR not found"
}

function detect_qt_version()
{
	qt_version=4
	test -d $QT_SOURCE_DIR/qtbase && qt_version=5
	echo "Qt major version = $qt_version"
}

#------------------------------------------------------------------------------
# Actions
#------------------------------------------------------------------------------

function action_setup_env()
{
	print_banner Setting up development environment
	assert_helper_scripts_exist
	execute $HELPER_SCRIPTS_DIR/setup-madde-toolchain.sh --force
}

function action_flash_device()
{
	print_banner Flashing device
	assert_superuser
	image_dir=$IMAGE_DIR/$VARIANT_DIR
	test -d $image_dir || error "Image dir $image_dir not found"
	cd $image_dir
	test -e $IMAGE_ROOT || error "Root image $IMAGE_ROOT not found"
	if [ ! -z "$IMAGE_EMMC" ]
	then
		test -e $IMAGE_EMMC || error "EMMC image $IMAGE_EMMC not found"
	fi
	test -e ../$IMAGE_KERNEL || error "Kernel $image_kernel not found"
	command_1="flasher -f -F $IMAGE_ROOT" #--erase-user-data=secure --erase-mmc=secure
	test -n "$IMAGE_EMMC" && command_1="$command_1 -F $IMAGE_EMMC"
	command_2="flasher -f -a $IMAGE_ROOT -k ../$IMAGE_KERNEL --reboot"
	execute $command_1
	execute $command_2
}

function action_setup_device()
{
	print_banner Setting up device
	assert_helper_scripts_exist
	execute $HELPER_SCRIPTS_DIR/setup-device.sh
}

function assert_chroot()
{
	test -z "$QT_HARMATTAN_CHROOT" && \
		error "QT_HARMATTAN_CHROOT not set"
}

function action_jail_create()
{
	assert_chroot
	local root=$QT_HARMATTAN_CHROOT
	print_banner Creating jail
	echo "Root = $root"
	test ! -d "$root" || error "Root $root already exists"
	execute sudo `which jail.sh` create $root
	execute mkdir -p $root/$PREFIX
}

# For debugging purposes only
function action_jail_enter()
{
	assert_chroot
	local root=$QT_HARMATTAN_CHROOT
	print_banner Entering jail
	echo "Root = $root"
	execute sudo `which jail.sh` enter $root
}

function action_jail_remove()
{
	assert_chroot
	local root=$QT_HARMATTAN_CHROOT
	print_banner Removing jail
	echo "Root = $root"
	assert_not_superuser
	execute sudo `which jail.sh` remove $root
	execute rm -rf $root
}

function action_configure()
{
	action_qt_configure
}

function action_qt_configure()
{
	print_banner Configuring Qt
	test ! -d $QT_INSTALL_DIR && execute mkdir -p $QT_INSTALL_DIR
	source $HELPER_SCRIPTS_DIR/setup-madde-toolchain.sh --force
	cd $QT_BUILD_DIR
	test "$opt_dryrun" == "yes" && extra_args="$extra_args --dry-run"
	test "$opt_verbosity" == "verbose" && extra_args="$extra_args --verbose"
	cmd="$SCRIPT_DIR/qt-configure.sh harmattan $extra_args --developer-build $dryrun"
	#local prefix_opts="--prefix $PREFIX --rpath $PREFIX/lib"
	#test "$qt_version" == "4" && prefix_opts="--prefix $QT_INSTALL_DIR --rpath $PREFIX/lib"
	#prefix_opts="--prefix $QT_INSTALL_DIR --rpath $PREFIX/lib"
	cmd="$cmd $prefix_opts"
	# For some reason, endianness detection fails when configuring Qt4
	test "$qt_version" == "4" && cmd="$cmd --extra=-little-endian --extra=-host-little-endian"
	echo $cmd
	$cmd
	for tool in $TOOLS
	do
		execute mkdir -p $QT_BUILD_DIR/tools/$tool
		execute cd $QT_BUILD_DIR/tools/$tool
		execute qmake $QT_SOURCE_DIR/tools/$tool
	done
}

function action_qt_build()
{
	print_banner Building Qt
	execute source $HELPER_SCRIPTS_DIR/setup-madde-toolchain.sh --force
	execute cd $QT_BUILD_DIR
	execute time make -j$(number_of_processors) install
	for tool in $TOOLS
	do
		execute cd $QT_BUILD_DIR/tools/$tool
		execute time make -j$(number_of_processors) install
	done
}

function action_clean()
{
	print_banner Cleaning
	execute cd $QT_SOURCE_DIR
	execute git submodule foreach --recursive 'git clean -fdx'
	execute git clean -fdx
	execute rm -rf $QT_BUILD_DIR
	execute mkdir -p $QT_BUILD_DIR
	execute rm -rf $QT_INSTALL_DIR
	execute mkdir -p $QT_INSTALL_DIR
	if [ ! -z "$QTMOBILITY_BUILD_DIR" ]
	then
		execute cd $QTMOBILITY_SOURCE_DIR
		execute git clean -fdx
		execute rm -rf $QTMOBILITY_BUILD_DIR
		execute mkdir -p $QTMOBILITY_BUILD_DIR
	fi
}

function deploy_dir()
{
	echo "deploy_dir $1 $2"
	local src=$1
	local dst=$2
	local remote="$REMOTE_USER@$REMOTE_HOSTNAME"

	# Ensure target directory exists
	if [ "$opt_dryrun" != "yes" ]
	then
		script=qt-harmattan-create-target-dir.sh
		rm -f /tmp/$script
		cat > /tmp/$script << EOF
dir=$dst
test ! -d \$dir && mkdir -p \$dir
EOF
		scp /tmp/$script $remote:
		ssh $remote /bin/sh \$HOME/$script
		ssh $remote rm -f \$HOME/$script
	fi

	# rsync
	cmd="execute rsync -azvvrl -e ssh $src $remote:$dst"
	exclude=
	test "$opt_deploy_debug" != "yes" && exclude="--exclude='*.debug' --delete-excluded"
	echo $cmd $exclude
	if [ "$opt_dryrun" != "yes" ]
	then
		if [ "$opt_deploy_debug" == "yes" ]
		then
			$cmd
		else
			$cmd --exclude='*.debug' --exclude='*.la' --exclude='*.prl' --delete-excluded
		fi
	fi
}

function deploy_qt()
{
	local qtdir=$PREFIX
	local remote="$REMOTE_USER@$REMOTE_HOSTNAME"
	if [ "$opt_dryrun" != "yes" ]
	then
		# Create and deploy .qtenvrc
		rm -f /tmp/qtenvrc
		cat > /tmp/qtenvrc << EOF
export QTDIR=$qtdir
echo "QTDIR=\$QTDIR"
export QT_IMPORT_PATH=\$QTDIR/imports
export QML_IMPORT_PATH=\$QTDIR/imports
export PATH=\$QTDIR/bin\${PATH:+:\$PATH}
EOF
		test "$qt_version" == '5' && cat >> /tmp/qtenvrc << EOF
export QT_PLUGIN_PATH=\$QTDIR/plugins
export QT_QPA_PLATFORM_PLUGIN=xcb
EOF
		scp /tmp/qtenvrc $remote:.qtenvrc

		# Source .qtenvrc from profile
		script=qt-harmattan-deploy-setup.sh
		rm -f /tmp/$script
		cat > /tmp/$script << EOF
if ! grep qtenvrc ~/.profile
then
	echo "source ~/.qtenvrc" >> ~/.profile
fi
EOF
		#scp /tmp/$script $remote:
		#ssh $remote /bin/sh \$HOME/$script
		#ssh $remote rm -f \$HOME/$script
	fi

	# Deploy binaries
	local src=$SYSROOT_DIR/$PREFIX
	test "$qt_version" == "4" && src=$QT_INSTALL_DIR
	local dst=$PREFIX
	for dir in $(ls $src)
	do
		deploy_dir $src/$dir $dst
	done
}

function action_mobility_configure()
{
	print_banner Configuring QtMobility
	source $HELPER_SCRIPTS_DIR/setup-madde-toolchain.sh --force
	cd $QTMOBILITY_BUILD_DIR
	test "$opt_dryrun" == "yes" && extra_args="$extra_args --dry-run"
	test "$opt_verbosity" == "verbose" && extra_args="$extra_args --verbose"
	cmd="$SCRIPT_DIR/qtmobility-configure.sh --harmattan $extra_args $dryrun -prefix $QT_INSTALL_DIR"
	echo $cmd
	$cmd
}

function action_mobility_build()
{
	print_banner Building QtMobility
	execute source $HELPER_SCRIPTS_DIR/setup-madde-toolchain.sh --force
	execute cd $QTMOBILITY_BUILD_DIR
	execute time make -j$(number_of_processors) install
}

function action_deploy()
{
	if [ -z "$extra_args" ]
	then
		print_banner Deploying Qt
		deploy_qt
	else
		print_banner Deploying directories
		for dir in $extra_args
		do
			local src=$SYSROOT_DIR/$PREFIX/$dir
			test "$qt_version" == "4" && src=$PREFIX/dir
			deploy_dir $src $PREFIX/$(dirname $dir)
		done
	fi
}

function action_build()
{
	test ! -e $QT_BUILD_DIR/Makefile && action_qt_configure
	action_qt_build
	if [ -n "$QTMOBILITY_BUILD_DIR" ]
	then
		test ! -e $QTMOBILITY_BUILD_DIR/Makefile && action_mobility_configure
		action_mobility_build
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

case $arg_action in
	flash-device | setup-device)
		;;
	*)
		test -z "$REMOTE_USER" && REMOTE_USER=$DEFAULT_REMOTE_USER
		test -z "$REMOTE_HOSTNAME" && REMOTE_HOSTNAME=$DEFAULT_REMOTE_HOSTNAME
		test -z "$PREFIX" && \
			error "QT_HARMATTAN_PREFIX not set"
		detect_qt_version
		test "$qt_version" == "4" && TOOLS=TOOLS_QT4
		;;
esac

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

if [ -z "$QT_INSTALL_DIR" ]
then
	echo "Setting QT_INSTALL_DIR to $QT_BUILD_DIR/../install"
	QT_INSTALL_DIR=$QT_BUILD_DIR/../install
fi

eval time action_${arg_action//-/_}

