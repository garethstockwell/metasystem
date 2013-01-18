# modules/climagic.sh

# Gems from http://www.climagic.org/

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function popup()
{
	if [[ $METASYSTEM_OS == windows ]]; then
		msg $(whoami) "$@"
	else
		xmessage -nearmouse "$@"
	fi
}

function delayed_popup()
{
	local delay=$1
	shift
	sleep $delay
	popup "$@"
}

# List disk usage for specified directory
function usage()
{
	local dir=$1
	[[ -z $dir ]] && dir=.
	ls -1A $dir | tr '\n' '\0' | xargs -0 du -sk | sort -n
}

#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------




