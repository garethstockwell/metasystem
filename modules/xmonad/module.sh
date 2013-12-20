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
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_XMONAD_BIN $PATH)

_metasystem_dotfile_register xmonad Xresources
_metasystem_dotfile_register xmonad xmonad.hs xmonad/xmonad.hs
_metasystem_dotfile_register xmonad xmonad-start xmonad/xmonad-start

