# modules/misc/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_MISC_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_MISC_BIN=$METASYSTEM_MISC_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_MISC_BIN $PATH)
