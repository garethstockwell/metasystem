# shrc-cygwin.sh

#------------------------------------------------------------------------------
# X
#------------------------------------------------------------------------------

export DISPLAY=127.0.0.1:0.0


#------------------------------------------------------------------------------
# Custom mounts
#------------------------------------------------------------------------------

function metasystem_cygwin_mount()
{
	local path=$1
	local mountpoint=$2
	if [[ -z `mount | grep $mountpoint` ]]; then
		echo "Mounting $path at $mountpoint"
		mount -f "$(metasystem_nativepath $path)" "$mountpoint"
	fi
}

metasystem_cygwin_mount $(cygpath -D -w) /desktop
metasystem_cygwin_mount ${HOME}/work/sync/git ${HOME}/git

