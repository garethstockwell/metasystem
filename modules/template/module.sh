# modules/xxx/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_XXX_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_XXX_BIN=$METASYSTEM_XXX_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_XXX_BIN $PATH)

