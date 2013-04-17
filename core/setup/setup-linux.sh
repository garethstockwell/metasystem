#!/usr/bin/env bash

# setup-linux

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
ARGUMENTS='recipe'

RECIPES='base android android-app android-plat java'
ALL_RECIPES='base android'

WORKGROUP=DIR

ANDROID_USER=$SUDO_USER

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
# Utility functions
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
setup-linux script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Arguments:
    recipe                  Recipe ($(list_pipe_separated $RECIPES))

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
setup-linux script version $SCRIPT_VERSION
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

	# Post processing
	test "$opt_yes" == "yes" && yes=-y
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

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

#------------------------------------------------------------------------------
# Generic Linux
#------------------------------------------------------------------------------

function setup_linux()
{
	create_smb_credentials
}

function create_smb_credentials()
{
	print_banner "Creating SMB credentials"
	credentials=/etc/samba/credentials
	credentials_dir=$(dirname $credentials)
	test -e $credentials && execute rm -f $credentials
	test ! -d $credentials_dir && execute mkdir -p $credentials_dir
	if [ "$opt_dryrun" != "yes" ]
	then
		cat > $credentials << EOF
domain=$WORKGROUP
username=$USER
EOF
	fi
}


#------------------------------------------------------------------------------
# Generic Debian
#------------------------------------------------------------------------------

function setup_debian()
{
	install_aptitude
	install_packages common
	#install_xplanetFX
}

function install_aptitude()
{
	print_banner Installing aptitude
	execute apt-get install aptitude
	execute aptitude $yes update
	execute aptitude $yes upgrade
}

function install_packages()
{
	local list=$1
	print_banner "Installing package list '$list'"
	execute `dirname $0`/linux/install-packages.sh $yes $list
}

function install_xplanetFX()
{
	print_banner "Installing xplanetFX"
	local tmp_dir=/tmp/xplanetFX
	execute rm -rf $tmp_dir
	execute mkdir -p $tmp_dir
	execute cd $tmp_dir
	execute curl http://repository.mein-neues-blog.de:9000/latest/xplanetFX.deb -o xplanetFX.deb
	execute dpkg -i xplanetFX.deb
	execute xplanetFX --autostart
	echo "Now run 'xplanetFX --setup' or 'xplanetFX --gui'"
}

function uninstall_xplanetFX()
{
	print_banner "Uninstalling xplanetFX"
	execute rm -r /usr/share/xplanetFX
	execute rm /usr/bin/xplanetFX
	execute rm /usr/share/pixmaps/xplanetFX.svg
	execute rm /usr/share/applications/xplanetFX.desktop
	execute rm -r ~/.xplanetFX
}


#------------------------------------------------------------------------------
# Ubuntu
#------------------------------------------------------------------------------

function setup_ubuntu()
{
	ubuntu_firewall_allow
	if "$METASYSTEM_OS_VERSION" == "11.10"
	then
		setup_ubuntu-11.10
	fi
}

function setup_ubuntu-11.10()
{
	ubuntu-11.10_libreoffice_enable_global_menu
	# Disabled for now due to network timeout when fetching key
	#ubuntu-11.10_install_application_indicators
}

function ubuntu_firewall_allow()
{
	print_banner "Adding firewall rule to allow incoming VNC and SSH connections"
	execute ufw allow 5900
	execute ufw allow 22
}

function ubuntu-11.10_disable_overlay_scrollbars()
{
	print_banner "Disabling overlay scrollbars"
	execute aptitude $yes remove overlay-scrollbar liboverlay-scrollbar3-0.2-0 liboverlay-scrollbar-0.2-0
	RESTART_REQUIRED=1
}

function ubuntu-11.10_enable_overlay_scrollbars()
{
	print_banner "Enabling overlay scrollbars"
	execute aptitude $yes install overlay-scrollbar liboverlay-scrollbar3-0.2-0 liboverlay-scrollbar-0.2-0
	RESTART_REQUIRED=1
}

function ubuntu-11.10_disable_global_menu()
{
	print_banner "Disabling global menu"
	execute aptitude $yes remove appmenu-gtk3 appmenu-gtk appmenu-qt
	RESTART_REQUIRED=1
}

function ubuntu-11.10_enable_global_menu()
{
	print_banner "Enabling global menu"
	execute aptitude $yes install appmenu-gtk3 appmenu-gtk appmenu-qt
	RESTART_REQUIRED=1
}

function ubuntu-11.10_libreoffice_enable_global_menu()
{
	print_banner "Enabling global menu for LibreOffice"
	execute aptitude $yes install lo-menubar
}

function ubuntu-11.10_libreoffice_disble_global_menu()
{
	print_banner "Disabling global menu for LibreOffice"
	execute aptitude $yes remove lo-menubar
}

function ubuntu-11.10_install_application_indicators()
{
	print_banner "Installing application indicators"
	# sysmonitor
	execute add-apt-repository -y ppa:alexeftimie/ppa
	execute aptitude $yes update
	execute aptitude $yes install indicator-sysmonitor
	# touchpad-indicator
	execute add-apt-repository -y ppa:atareao/atareao
	execute aptitude $yes update
	execute aptitude $yes install touchpad-indicator
	# battery-status
	execute apt-add-repository -y ppa:iaz/battery-status
	execute aptitude $yes update
	execute aptitude $yes install battery-status
}


#------------------------------------------------------------------------------
# Java
#------------------------------------------------------------------------------

function setup_java()
{
	print_banner "Setting up Java"

	#test "$opt_dryrun" != "yes" &&\
	#	add-apt-repository -y "deb http://archive.canonical.com/ lucid partner"
	#execute add-apt-repository -y ppa:ferramroberto/java
	#execute aptitude $yes update

	local jdk_bin=~/Downloads/jdk.bin
	local jdk_dir=/opt/java
	local jdk_tmp_dir=/tmp/java

	test -d $jdk_dir && echo "JDK already installed in $jdk_dir" && return 0

	test -e $jdk_bin || error "JDK file $jdk_bin not found: download from http://www.java.com/en/download/linux_manual.jsp?locale=en"
	execute rm -rf $jdk_dir
	execute mkdir -p $jdk_dir
	execute rm -rf $jdk_tmp_dir
	execute mkdir -p $jdk_tmp_dir
	execute cd $jdk_tmp_dir
	execute chmod +x $jdk_bin
	execute $jdk_bin
	if [ "$opt_dryrun" != "yes" ]
	then
		for dir in `find . -mindepth 2 -maxdepth 2 -type d`
		do
			mv $dir $jdk_dir
		done
	fi
	for file in $('ls' $jdk_dir/bin); do
		local new_file=$jdk_dir/bin/$file
		local sys_file=/usr/bin/$file
		if [[ -e $sys_file ]]; then
			execute update-alternatives --install "$sys_file" "$file" "$new_file" 1
			execute update-alternatives --set $file $new_file
		fi
	done
}


#------------------------------------------------------------------------------
# Android
# See http://source.android.com/source/initializing.html
#------------------------------------------------------------------------------

function android_setup_app()
{
	print_banner "Setting up Android app development tools"
	setup_java
	install_packages android-dev-app
}

function android_setup_platform()
{
	print_banner "Setting up Android platform development tools"
	install_packages android-dev-plat
	if [ -d /usr/lib32/mesa ]
	then
		execute rm -f /usr/lib32/mesa/libGL.so
		execute ln -s /usr/lib32/mesa/libGL.so.1 /usr/lib32/mesa/libGL.so
	fi
	#execute rm -f /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1
	#execute ln -s /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1 /usr/lib/libGL.so
	android_setup_usb
}

function android_setup_usb()
{
	print_banner "Setting up USB access for Android"
	local rules=/etc/udev/rules.d/51-android.rules
	execute rm -f $rules
	if [ "$opt_dryrun" != "yes" ]
	then
		echo "
# adb protocol on passion (Nexus One)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e12\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on passion (Nexus One)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0bb4\", ATTR{idProduct}==\"0fff\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on crespo/crespo4g (Nexus S)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e22\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on crespo/crespo4g (Nexus S)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e20\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on stingray/wingray (Xoom)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"22b8\", ATTR{idProduct}==\"70a9\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on stingray/wingray (Xoom)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"708c\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on maguro/toro (Galaxy Nexus)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04e8\", ATTR{idProduct}==\"6860\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on maguro/toro (Galaxy Nexus)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e30\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on panda (PandaBoard)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0451\", ATTR{idProduct}==\"d101\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on panda (PandaBoard)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0451\", ATTR{idProduct}==\"d022\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# usbboot protocol on panda (PandaBoard)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0451\", ATTR{idProduct}==\"d010\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on grouper/tilapia (Nexus 7)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e42\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on grouper/tilapia (Nexus 7)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4e40\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# adb protocol on manta (Nexus 10)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4ee2\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
# fastboot protocol on manta (Nexus 10)
SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", ATTR{idProduct}==\"4ee0\", MODE=\"0600\", OWNER=\"$ANDROID_USER\"
" > $rules
	fi
}


#------------------------------------------------------------------------------
# Recipes
#------------------------------------------------------------------------------

function recipe_base()
{
	setup_linux
	setup_debian
	setup_ubuntu
}

function recipe_android()
{
	android_setup_app
	android_setup_platform
}

function recipe_android_app()
{
	android_setup_app
}

function recipe_android_plat()
{
	android_setup_platform
}

function recipe_java()
{
	setup_java
}

function execute_recipe()
{
	local recipe=$1
	local function=recipe_${recipe//-/_}
	eval $function
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

assert_is_ubuntu

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

assert_superuser

if [ "$arg_recipe" == "all" ]
then
	for recipe in $ALL_RECIPES
	do
		execute_recipe $recipe
	done
else
	if [ -z "$(list_contains $arg_recipe $RECIPES)" ]
	then
		error "Invalid recipe $arg_recipe"
	else
		execute_recipe $arg_recipe
	fi
fi

if [ "$RESTART_REQUIRED" == "1" ]
then
	print_banner "Restart required"
	echo "A system restart is required in order to apply the changes"
fi

