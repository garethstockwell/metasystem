# modules/climagic.sh

# Gems from http://www.climagic.org/

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function popup()
{
	xmessage -nearmouse "$@"
}

function delayed_popup()
{
	local delay=$1
	shift
	sleep $delay
	popup "@"
}

function scp()
{
	if [[ "$@" =~ : ]]; then
		$(which scp) $@
	else
		echo "Error: missing colon" >&2
		return 1
	fi
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------




