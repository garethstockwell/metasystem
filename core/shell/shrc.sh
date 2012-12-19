# shrc.sh

#------------------------------------------------------------------------------
# OS / platform
#------------------------------------------------------------------------------

# TODO: set METASYSTEM_OS_VERSION on Windows
# http://www.windows-commandline.com/2009/01/find-windows-os-version-from-command.html

METASYSTEM_OS=unknown
METASYSTEM_OS_VENDOR=unknown
METASYSTEM_OS_VERSION=unknown
METASYSTEM_PLATFORM=unknown

if [[ -n `uname | grep -i ^cygwin` ]]; then
	METASYSTEM_OS=windows
	METASYSTEM_OS_VENDOR=microsoft
	METASYSTEM_PLATFORM=cygwin
	export CYGWIN_HOME=/cygdrive/c/cygwin
fi

if [[ -n `uname | grep -i ^mingw` ]]; then
	METASYSTEM_OS=windows
	METASYSTEM_OS_VENDOR=microsoft
	METASYSTEM_PLATFORM=mingw
	export MSYS_HOME=/c/MinGW/msys/1.0
	export TERM=msys
fi

if [[ -n `uname | grep -i ^darwin` ]]; then
	METASYSTEM_OS=mac
	METASYSTEM_OS_VENDOR=apple
	METASYSTEM_OS_VERSION=`sw_vers -productVersion`
	METASYSTEM_PLATFORM=unix
fi

if [[ -n `uname | grep -i ^sunos` ]]; then
	METASYSTEM_OS=sunos
	METASYSTEM_OS_VENDOR=sun
	METASYSTEM_OS_VERSION=
	METASYSTEM_PLATFORM=unix
fi

if [[ $METASYSTEM_OS == unknown && -e /etc/issue ]]; then
	METASYSTEM_OS=linux
	METASYSTEM_OS_VENDOR=`cat /etc/issue | awk '{ print $1 }' | tr 'A-Z' 'a-z'`
	METASYSTEM_OS_VERSION=`cat /etc/issue | awk '{ print $2 }' | tr 'A-Z' 'a-z'`
	METASYSTEM_PLATFORM=unix
fi

export METASYSTEM_OS
export METASYSTEM_OS_VENDOR
export METASYSTEM_OS_VERSION
export METASYSTEM_PLATFORM
export METASYSTEM_HOSTNAME=$HOSTNAME


#------------------------------------------------------------------------------
# Home
#------------------------------------------------------------------------------

# Ensure that we start in the home directory
cd $HOME

# Find location of this script
export METASYSTEM_ROOT=$( builtin cd $(dirname ${BASH_SOURCE:-$0})/../.. && pwd )

export METASYSTEM_CORE_ROOT=$METASYSTEM_ROOT/core
export METASYSTEM_CORE_BIN=$METASYSTEM_CORE_ROOT/bin
export METASYSTEM_CORE_LIB=$METASYSTEM_CORE_ROOT/lib
export METASYSTEM_CORE_SHELL=$METASYSTEM_CORE_ROOT/shell
export METASYSTEM_CORE_TEMPLATES=$METASYSTEM_CORE_ROOT/templates

export METASYSTEM_CORE_LIB_BASH=$METASYSTEM_CORE_LIB/bash

if [[ -n $METASYSTEM_LOCAL_ROOT ]]; then
	metasystem_local_root=$METASYSTEM_LOCAL_ROOT
else
	metasystem_local_root=$METASYSTEM_CORE_ROOT/../metasystem-local
fi

if [[ -d $metasystem_local_root ]]; then
	export METASYSTEM_LOCAL_ROOT=$(cd $metasystem_local_root && pwd)
	export METASYSTEM_LOCAL_BIN=$METASYSTEM_LOCAL_ROOT/bin
	export METASYSTEM_LOCAL_LIB=$METASYSTEM_LOCAL_ROOT/lib
	export METASYSTEM_LOCAL_SHELL=$METASYSTEM_LOCAL_ROOT/shell
	export METASYSTEM_LOCAL_TEMPLATES=$METASYSTEM_LOCAL_ROOT/templates
	export METASYSTEM_CORE_CONFIG=$METASYSTEM_LOCAL_ROOT/config

	export METASYSTEM_LOCAL_LIB_BASH=$METASYSTEM_LOCAL_LIB/bash
else
	export METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config
fi


#------------------------------------------------------------------------------
# Config
#------------------------------------------------------------------------------

# Import config
source $METASYSTEM_CORE_SHELL/config.sh


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

# Import utility functions
source $METASYSTEM_CORE_LIB_BASH/utils.sh
source $METASYSTEM_CORE_LIB_BASH/path.sh
source $METASYSTEM_CORE_LIB_BASH/string.sh


#------------------------------------------------------------------------------
# Autoload
#------------------------------------------------------------------------------

for dir in $METASYSTEM_CORE_LIB/autoload \
	       $METASYSTEM_CORE_LIB/autoload/$METASYSTEM_PLATFORM; do
	export FPATH=$dir:$FPATH
	for file in $(find $dir -type f 2>/dev/null); do
		autoload $(basename $file)
	done
done


#------------------------------------------------------------------------------
# Profile
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_SHELL/profile.sh


#------------------------------------------------------------------------------
# Misc setup
#------------------------------------------------------------------------------

# cgrep
# 1;32 = bright green
# See	http://www.termsys.demon.co.uk/vtansi.htm#colors
#		http://www.debian-administration.org/articles/460
export GREP_COLOR='1;32'

# X server forwarding
[[ $METASYSTEM_PLATFORM == cygwin ]] && export DISPLAY=127.0.0.1:0.0

# Git colorizer
export PAGER='less -R'


#------------------------------------------------------------------------------
# Utility functions: window titles
#------------------------------------------------------------------------------

# Function to set window title
function xterm_set_title()
{
	case $TERM in
		*term | rxvt)
			echo -n -e "\033]0;$*\007" ;;
		*)  ;;
	esac
}


#------------------------------------------------------------------------------
# Utility functions: misc
#------------------------------------------------------------------------------

# Empty function
function empty_function()
{
	echo > /dev/null
}


#------------------------------------------------------------------------------
# Apps
#------------------------------------------------------------------------------

[[ $METASYSTEM_PLATFORM == cygwin ]] && _METASYSTEM_APPS=/cygdrive/c/apps
[[ $METASYSTEM_PLATFORM == mingw ]] && _METASYSTEM_APPS=/c/apps
[[ -z $_METASYSTEM_APPS ]] && _METASYSTEM_APPS=~/apps


#------------------------------------------------------------------------------
# Platform
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_SHELL/shrc-$METASYSTEM_PLATFORM.sh
os_rc=$METASYSTEM_CORE_SHELL/shrc-$METASYSTEM_OS.sh
[[ -e $os_rc ]] && source $os_rc
unset os_rc


#------------------------------------------------------------------------------
# Python check
#------------------------------------------------------------------------------

have_python=`which python`


#------------------------------------------------------------------------------
# PATH
#------------------------------------------------------------------------------

PATH=$HOME/bin:$PATH

# Editor
METASYSTEM_EDITOR=vi

# Misc apps
PATH=$(path_prepend_if_exists $_METASYSTEM_APPS/bin $PATH)

# Misc tools
PATH=$METASYSTEM_CORE_BIN:${PATH}

# Templater
PATH=$(path_append_if_exists ~/work/sync/git/templater/bin $PATH)

# stuff
[[ -d $METASYSTEM_CORE_ROOT/../stuff ]] && source $METASYSTEM_CORE_ROOT/../stuff/bashrc-stuff

PATH=$(path_remove '^\.$' $PATH)

[[ -d $VIM_HOME ]] && export METASYSTEM_EDITOR=$(metasystem_nativepath $VIM_HOME/vim.exe)

