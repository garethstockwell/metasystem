# shrc-cygwin.sh

#------------------------------------------------------------------------------
# Path handling
#------------------------------------------------------------------------------

function metasystem_drivepath()
{
	local letter=$(metasystem_driveletter $1)
	[[ -n $letter ]] && echo /cygdrive/$letter
}

function metasystem_driveletter()
{
	echo $1 | sed -e 's/\/cygdrive\/\([a-z]\).*/\1/'
}

function metasystem_nativepath()
{
	[[ -n $1 ]] && cygpath -w $1
}

function metasystem_unixpath()
{
	[[ -n $1 ]] && cygpath $1
}


#------------------------------------------------------------------------------
# Custom mounts
#------------------------------------------------------------------------------

if [[ -z `mount | grep desktop` ]]; then
	desktop=`cygpath -D -w`
	echo "Desktop = $desktop"
	mount "$desktop" /desktop
fi
