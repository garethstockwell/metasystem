# profile

#------------------------------------------------------------------------------
# OS / platform
#------------------------------------------------------------------------------

# TODO: set METASYSTEM_OS_VERSION on Windows
# http://www.windows-commandline.com/2009/01/find-windows-os-version-from-command.html

METASYSTEM_OS=unknown
METASYSTEM_OS_VENDOR=unknown
METASYSTEM_OS_VERSION=unknown
METASYSTEM_PLATFORM=unknown

uname_out=$(uname)

case $uname_out in
	[Mm][Ii][Nn][Gg][Ww]*)
		METASYSTEM_OS=windows
		METASYSTEM_OS_VENDOR=microsoft
		METASYSTEM_PLATFORM=mingw
		export MSYS_HOME=/c/MinGW/msys/1.0
		export TERM=msys
		;;

	[Cc][Yy][Gg][Ww][Ii][Nn]*)
		METASYSTEM_OS=windows
		METASYSTEM_OS_VENDOR=microsoft
		METASYSTEM_PLATFORM=cygwin
		export CYGWIN_HOME=/cygdrive/c/cygwin
		;;

	[Ll][Ii][Nn][Uu][Xx]*)
		METASYSTEM_OS=linux
		METASYSTEM_OS_VENDOR=
		METASYSTEM_OS_VERSION=
		METASYSTEM_PLATFORM=unix
		;;

	[Dd][Aa][Rr][Ww][Ii][Nn]*)
		METASYSTEM_OS=mac
		METASYSTEM_OS_VENDOR=apple
		METASYSTEM_OS_VERSION=`sw_vers -productVersion`
		METASYSTEM_PLATFORM=unix
		;;

	[Ss][Uu][Nn][Oo][Ss]*)
		METASYSTEM_OS=sunos
		METASYSTEM_OS_VENDOR=sun
		METASYSTEM_OS_VERSION=
		METASYSTEM_PLATFORM=unix
		;;

	*)
		if [[ -e /etc/issue ]]; then
			METASYSTEM_OS=linux
			METASYSTEM_OS_VENDOR=`cat /etc/issue | awk '{ print $1 }' | tr 'A-Z' 'a-z'`
			METASYSTEM_OS_VERSION=`cat /etc/issue | awk '{ print $2 }' | tr 'A-Z' 'a-z'`
			METASYSTEM_PLATFORM=unix
		fi
esac

unset uname_out

export METASYSTEM_OS
export METASYSTEM_OS_VENDOR
export METASYSTEM_OS_VERSION
export METASYSTEM_PLATFORM
export METASYSTEM_HOSTNAME=$HOSTNAME


#------------------------------------------------------------------------------
# Misc stuff
#------------------------------------------------------------------------------

export METASYSTEM_CORE_ROOT=$METASYSTEM_ROOT/core
export METASYSTEM_CORE_BIN=$METASYSTEM_CORE_ROOT/bin
export METASYSTEM_CORE_LIB=$METASYSTEM_CORE_ROOT/lib
export METASYSTEM_CORE_SHELL=$METASYSTEM_CORE_ROOT/shell
export METASYSTEM_CORE_TEMPLATES=$METASYSTEM_CORE_ROOT/templates

export METASYSTEM_CORE_LIB_BASH=$METASYSTEM_CORE_LIB/bash

if [[ -n $METASYSTEM_LOCAL_ROOT ]]; then
	metasystem_local_root=$METASYSTEM_LOCAL_ROOT
else
	metasystem_local_root=$METASYSTEM_ROOT/../metasystem-local
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
# Misc stuff
#------------------------------------------------------------------------------

export EDITOR=vim

# cgrep
# 1;32 = bright green
# See	http://www.termsys.demon.co.uk/vtansi.htm#colors
#		http://www.debian-administration.org/articles/460
export GREP_COLOR='1;32'



