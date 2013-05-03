# modules/android/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_android_emulator()
{
	local exe=$(which emulator-arm)
	if [[ -z $exe ]]; then
		echo "Error: emulator not found"
		return 1
	fi

	# Parse command line
	local args=
	local avd=
	local opt_help=
	local opt_sdcard=
	local opt_observe=1
	local opt_verbose=1
	local opt_dryrun=

	[[ -n $ANDROID_SDCARD_IMG && -d $(dirname $ANDROID_SDCARD_IMG) ]] &&\
		opt_sdcard="$ANDROID_SDCARD_IMG"

	local prev=

	for token in "$@"; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		local append=
		case $token in
			-h | --help)
				args="$args -help"
				opt_help=1
				opt_observe=
				;;
			-help)
				opt_observe=
				append=1
				;;
			-sdcard)
				prev=opt_sdcard
				;;
			-observe | --observe)
				opt_observe=1
				;;
			-no-observe | --no-observe)
				opt_observe=
				;;
			-verbose | --verbose)
				opt_verbose=1
				;;
			-no-verbose | --no-verbose | -quiet | --quiet)
				opt_verbose=
				;;
			-n | -dryrun | -dry-run | --dryrun | --dry-run)
				opt_dryrun=1
				;;
			-avd | @*)
				avd=1
				;;
			*)
				append=1
				;;
		esac
		[[ -n $append ]] && args="$args $token"
	done

	echo "args=$args"

	# Compose command
	local cmd="$exe $args"
	[[ -n $opt_verbose ]] && cmd="$cmd -verbose -show-kernel"

	# We don't need to use an AVD
	#[[ -z $avd && -n $ANDROID_DEFAULT_AVD ]] && cmd="$cmd @$ANDROID_DEFAULT_AVD"

	# Create SD card image
	if [[ -n $opt_sdcard ]]; then
		if [[ ! -e $opt_sdcard ]]; then
			if [[ -n $(which mksdcard) ]]; then
				echo "Creating sdcard image $opt_sdcard with size $ANDROID_EMULATOR_SDCARD_SIZE"
				if [[ -z $opt_dryrun ]]; then
					mkdir -p $(dirname $opt_sdcard)
					mksdcard -l e $ANDROID_EMULATOR_SDCARD_SIZE $opt_sdcard
				fi
			else
				echo "mksdcard not found"
				opt_sdcard=
			fi
		fi
	fi
	[[ -n $opt_sdcard ]] && cmd="$cmd -sdcard $opt_sdcard"

	# Launch
	echo $cmd
	local r=0
	if [[ -z $opt_dryrun ]]; then
		[[ -n $opt_observe ]] && metasystem_android_observe
		$cmd
		r=$?
		[[ -n $opt_help ]] && cat << EOF
Additional options (metasystem):
  -observe, --observe          Spawn ADB shell and logcat windows
  -no-observe, --no-observe    Do not spawn ADB shell and logcat windows
  -verbose, --verbose          Verbose output and show kernel messages
  -no-verbose, --no-verbose    Disable verbose output and suppress kernel messages
EOF
	fi
	return $r
}

# Spawn two windows, one showing logcat output and the other with an
# 'adb shell' session
function metasystem_android_observe()
{
	local gt=$(which gnome-terminal 2>/dev/null)
	local size=100x25
	if [[ -n $gt ]]; then
		$gt --title="adb logcat" --geometry="${size}+0+0" -x bash -c android-adb-logcat.py
		$gt --title="adb shell" --geometry="${size}+0-0" -x bash -c "adb wait-for-device && adb shell"
	else
		echo "Error: gnome-terminal not found" >&2
	fi
}

function metasystem_android_ndk_build()
{
	local exe=$(which ndk-build)
	if [[ -z $exe ]]; then
		echo "Error: ndk-build not found"
		return 1
	fi

	# Parse command line
	local args=
	local opt_help=
	local opt_log=
	local opt_debug=
	for token in "$@"; do
		local append=
		case $token in
			-h | -help | --help)
				opt_help=1
				append=1
				;;
			-log | --log)
				opt_log=1
				;;
			-no-log | --no-log)
				opt_log=
				;;
			-g | --g)
				opt_debug=1
				;;
			*)
				append=1
				;;
		esac
		[[ -n $append ]] && args="$args $token"
	done
	[[ -n $opt_log ]] && args="$args NDK_LOG=1"
	[[ -n $opt_debug ]] && args="$args NDK_DEBUG=1"

	local cmd="$exe $args"
	echo $cmd
	$cmd
	local r=$?
	[[ -n $opt_help ]] && cat << EOF

Additional options (metasystem):
  -log, --log                  Verbose output (NDK_LOG=1)
  -g                           Enable debugging (NDK_DEBUG=1)
EOF
	return $r
}

function metasystem_android_cd_src()
{
	[[ -n $ANDROID_SRC && -d $ANDROID_SRC ]] &&\
		metasystem_cd $ANDROID_SRC
}

function metasystem_android_cd_build()
{
	[[ -n $ANDROID_BUILD_TOP && -d $ANDROID_BUILD_TOP ]] &&\
		metasystem_cd $ANDROID_BUILD_TOP
}

function metasystem_android_cd_product_out()
{
	[[ -n $ANDROID_PRODUCT_OUT && -d $ANDROID_PRODUCT_OUT ]] &&\
		metasystem_cd $ANDROID_PRODUCT_OUT
}

function metasystem_android_shell()
{
	adb wait-for-device && adb shell "$@"
}

# Pull kernel config from running device
function metasystem_android_pull_kconfig()
{
	[[ -z $ANDROID_SRC ]] && echo "Error: ANDROID_SRC not set" >&2 && return 1
	local kernel=$1
	[[ -z $kernel ]] && echo "Usage: android-pull-kconfig <kernel>" >&2 && return 1
	[[ ! -d $ANDROID_SRC/kernel/$kernel ]] && echo "Error: $ANDROID_SRC/kernel/$kernel not found" >&2 && return 1
	cd $ANDROID_SRC/kernel/$kernel
	[[ -e .config ]] && echo "Error: $ANDROID_SRC/kernel/$kernel/.config already exists" >&2 && return 1
	rm -f config.gz
	adb pull /proc/config.gz
	gunzip config.gz
	mv config .config
	echo "Kernel config pulled to $(pwd)/.config"
	rm -f config.gz
}

function metasystem_android_find_binary_local()
{
	[[ -z $ANDROID_PRODUCT_OUT ]] &&\
		echo "Error: ANDROID_PRODUCT_OUT not set" >&2 &&\
		return 1
	result=$(find $ANDROID_PRODUCT_OUT/system -iname "$@")
	[[ -z $result ]] &&\
		echo "Error: '$@' not found in local \$ANDROID_PRODUCT_OUT/system" >&2 &&\
		return 1
	[[ $(echo $result | wc -w) != 1 ]] &&\
		echo "Error: '$@' matches multiple local files in \$ANDROID_PRODUCT_OUT/system:" >&2 &&\
		for a in $result; do echo $a >&2; done &&\
		return 1
	echo $result
}

function metasystem_android_find_binary_remote()
{
	result=$(adb shell "find /system -iname \"$@\" 2>&1")
	[[ -z $result ]] &&\
		echo "Error: '$@' not found in remote /system" >&2 &&\
		return 1
	[[ $(echo $result | wc -w) != 1 ]] &&\
		echo "Error: '$@' matches multiple files in remote /system:" >&2 &&\
		for a in $result; do echo $a >&2; done &&\
		return 1
	echo $result | tr -d '\015'
}

# Push binary to device
function metasystem_android_push_binary()
{
	local cmd="adb remount"
	echo $cmd && $cmd
	[[ $? != 0 ]] && return $?
	local ret=0
	for file in "$@"; do
		local src=$(metasystem_android_find_binary_local $file)
		local dst=$(metasystem_android_find_binary_remote $file)
		cmd="adb push $src $dst"
		echo $cmd && $cmd
		[[ $? != 0 ]] && ret=$?
		local src_sum=$(md5sum $src | awk '{ print $1 }')
		[[ $? != 0 ]] && ret=$?
		local dst_sum=$(adb shell "md5sum $dst | awk '{ print \$1 }'" | tr -d '\015')
		[[ $? != 0 ]] && ret=$?
		if [[ $src_sum != $dst_sum ]]; then
			src_sum=$(echo $src_sum | head -c8)
			dst_sum=$(echo $dst_sum | head -c8)
			echo "Error: checksum mismatch ($src_sum vs $dst_sum)"
			ret=1
		else
			echo "OK: checksum $src_sum"
		fi
	done
	return $ret
}


#------------------------------------------------------------------------------
# Functions which require the ssh module
#------------------------------------------------------------------------------

function metasystem_android_ssh_port_fwd_config()
{
	export SSH_PORT_FWD_SERVICES='adb gdb'

	export SSH_PORT_FWD_SERVICE_adb_local_base=5037
	export SSH_PORT_FWD_SERVICE_adb_remote_offset=0
	export SSH_PORT_FWD_SERVICE_adb_count=1

	export SSH_PORT_FWD_SERVICE_gdb_local_base=
	export SSH_PORT_FWD_SERVICE_gdb_local_offset=1
	export SSH_PORT_FWD_SERVICE_gdb_remote_offset=1
	export SSH_PORT_FWD_SERVICE_gdb_count=10
}

function metasystem_android_ssh_port_fwd_client()
{
	metasystem_android_ssh_port_fwd_config
	ssh-port-fwd.sh "$@"
}

function metasystem_android_ssh_port_fwd_server()
{
	metasystem_android_ssh_port_fwd_config
	local base=$(eval $SSH_PORT_FWD_REMOTE_BASE_CMD)
	export ANDROID_ADB_SERVER_PORT=$( __ssh_port_fwd_remote_port $base adb 1)
	export CODEEXPLORER_GDB_SERVER_PORT=$( __ssh_port_fwd_remote_port $base gdb 1)
}

# Sometimes ADB port forwarding stops working; creating a telnet connection
# to the local port seems to wake it up...
alias adb-poke="adb kill-server; telnet localhost $ANDROID_ADB_SERVER_PORT"


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_ANDROID_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_ANDROID_BIN=$METASYSTEM_ANDROID_ROOT/bin

export ANDROID_HOST_SSH_PORT=9999
export ANDROID_TARGET_SSH_PORT=2222

export ANDROID_DEFAULT_AVD=15

export ANDROID_EMULATOR_SDCARD_SIZE=512M
export ANDROID_SDK_DIR=~/work/local/sdks/android/aosp/sdk
export ANDROID_NDK_DIR=~/work/local/sdks/android/aosp/ndk

export ANDROID_AUTO_LUNCH=1
export ANDROID_SET_KERNEL_COMPILATION_VARS=1


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias acds=metasystem_android_cd_src
alias acdb=metasystem_android_cd_build
alias acdp=metasystem_android_cd_product_out

alias android-emulator=metasystem_android_emulator
alias android-observe=metasystem_android_observe
alias ndk-build=metasystem_android_ndk_build
alias android-shell=metasystem_android_shell
alias adb=android-adb.sh
alias android-pull-kconfig=metasystem_android_pull_kconfig
alias android-push-binary=metasystem_android_push_binary


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_hook_android_prompt()
{
	if [[ -n $TARGET_PRODUCT && -n $TARGET_BUILD_VARIANT ]]; then
		echo "${LIGHT_GREEN}android: ${TARGET_PRODUCT}-${TARGET_BUILD_VARIANT}${NO_COLOR}"
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_ANDROID_BIN $PATH)

source $METASYSTEM_ANDROID_ROOT/shell/bash-completion.sh

if [[ -d $ANDROID_SDK_DIR ]]; then
	PATH=$(path_prepend $ANDROID_SDK_DIR/platform-tools $PATH)
	PATH=$(path_prepend $ANDROID_SDK_DIR/tools $PATH)
fi

if [[ -d $ANDROID_NDK_DIR ]]; then
	PATH=$(path_prepend $ANDROID_NDK_DIR $PATH)
fi

