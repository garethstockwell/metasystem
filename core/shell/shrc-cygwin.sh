# shrc-cygwin.sh

#------------------------------------------------------------------------------
# Custom mounts
#------------------------------------------------------------------------------

if [[ -z `mount | grep desktop` ]]; then
	desktop=`cygpath -D -w`
	echo "Desktop = $desktop"
	mount "$desktop" /desktop
fi

