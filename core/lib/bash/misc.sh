# lib/bash/misc.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function assert_superuser()
{
	test `whoami` == "root" || error "Must be run as superuser"
}

function assert_not_superuser()
{
	test `whoami` != "root" || error "Must not be run as superuser"
}

function check_os()
{
	METASYSTEM_OS=
	METASYSTEM_OS_VENDOR=
	METASYSTEM_OS_VERSION=
	METASYSTEM_PLATFORM=

	if [ ! -z `uname | grep -i ^cygwin` ]
	then
		METASYSTEM_OS=windows
		METASYSTEM_OS_VENDOR=microsoft
		METASYSTEM_PLATFORM=cygwin
		export CYGWIN_HOME=/cygdrive/c/cygwin
	fi

	if [ ! -z `uname | grep -i ^mingw` ]
	then
		METASYSTEM_OS=windows
		METASYSTEM_OS_VENDOR=microsoft
		METASYSTEM_PLATFORM=mingw
		export MSYS_HOME=/c/MinGW/msys/1.0
		export TERM=msys
	fi

	if [ ! -z `uname | grep -i ^darwin` ]
	then
		METASYSTEM_OS=mac
		METASYSTEM_OS_VENDOR=apple
		METASYSTEM_OS_VERSION=`sw_vers -productVersion`
		METASYSTEM_PLATFORM=unix
	fi

	if [ -e /etc/issue ]
	then
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
}

function assert_is_linux()
{
	test "$METASYSTEM_OS" == "linux" || error "Not Linux"
}

function assert_is_ubuntu()
{
	assert_is_linux
	test "$METASYSTEM_OS_VENDOR" == "ubuntu" || error "Not Ubuntu"
}

function log_file()
{
	local dir_var=$1
	local dir=$(eval echo \$$dir_var)
	local label=$2
	[[ -n $label ]] && label=${label}-
	if [[ -n $dir ]]; then
		if [[ -d $dir ]]; then
			local timestamp=$(date +%y%m%d-%H%M%S)
			local filename="$dir/$label$timestamp.log"
			local index=0
			while [[ -e $filename ]]; do
				index=$(($index+1))
				filename="$dir/$label$timestamp-$(printf %03d $index).log"
			done
		else
			echo "Error: log directory '$dir' not found" >&2
		fi
	fi
	echo $filename
}

