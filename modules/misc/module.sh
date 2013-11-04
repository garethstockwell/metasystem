# modules/misc/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Run to fix erroneous "you are already logged in on this computer" login
# failure
function skype_remove_lock()
{
	local skype_dir=$HOME/.Skype
	rm -fv $(find ${skype_dir} -iname *.lock)
	rm -fv $(find ${skype_dir} -iname *.lck)
}

# Run to fix erroneous "Firefox already running" startup failure
function firefox_remove_lock()
{
	local firefox_dir=$HOME/.mozilla/firefox
	rm -fv $(find ${firefox_dir} -iname lock)
	rm -fv $(find ${firefox_dir} -iname .parentlock)
}



#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_MISC_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_MISC_BIN=$METASYSTEM_MISC_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_MISC_BIN $PATH)

