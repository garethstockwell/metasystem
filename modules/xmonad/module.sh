# modules/xmonad.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists xmonad || return 1


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_XMONAD_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_XMONAD_BIN=$METASYSTEM_XMONAD_ROOT/bin


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function xmonad_recompile()
{
	_metasystem_dotfile_update xmonad &&\
	xmonad --recompile
}

function xmonad_restart()
{
	killall -9 dzen2
	killall -9 conky
	killall -9 trayer
	xmonad_recompile &&\
	xrdb < ~/.Xresources &&\
	xmonad --restart
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_XMONAD_BIN $PATH)

_metasystem_dotfile_register xmonad conkyrc xmonad/conkyrc %
_metasystem_dotfile_register xmonad xmonad.hs xmonad/xmonad.hs
_metasystem_dotfile_register xmonad xmonad-start xmonad/xmonad-start
_metasystem_dotfile_register xmonad xmobar.hs xmonad/xmobar.hs
_metasystem_dotfile_register xmonad Xresources

