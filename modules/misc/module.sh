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

# Run to remove corrupted xmarks db
function firefox_remove_xmarks()
{
	local firefox_dir=$HOME/.mozilla/firefox
	rm -fv $(find ${firefox_dir} -iname *.sqlite*)
	rm -fv $(find ${firefox_dir} -iname xmarks*)
}

function edit_source()
{
	local dirs="$@"
	[[ -n $dirs ]] || dirs=$PWD
	local files=
	for dir in $dirs; do
		for suffix in h hpp hxx cpp; do
			files="$files $(find $dir -iname *.$suffix)"
		done
		files="$files $(find $dir -iname *.c | grep -v mod.c)"
	done
	vim $files
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

_metasystem_dotfile_register misc astylerc
_metasystem_dotfile_register misc inputrc

