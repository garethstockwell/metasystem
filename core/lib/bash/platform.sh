# lib/bash/platform.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function query_platform()
{
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
				METASYSTEM_OS_VENDOR=
				METASYSTEM_OS_VERSION=
				METASYSTEM_PLATFORM=unix
			fi
	esac

	if [[ METASYSTEM_OS == 'linux' && -e /etc/issue ]]; then
		METASYSTEM_OS_VENDOR=`cat /etc/issue | awk '{ print $1 }' | tr 'A-Z' 'a-z'`
		METASYSTEM_OS_VERSION=`cat /etc/issue | awk '{ print $2 }' | tr 'A-Z' 'a-z'`
	fi

	unset uname_out

	export METASYSTEM_OS
	export METASYSTEM_OS_VENDOR
	export METASYSTEM_OS_VERSION
	export METASYSTEM_PLATFORM
	export METASYSTEM_HOSTNAME=$HOSTNAME
}

