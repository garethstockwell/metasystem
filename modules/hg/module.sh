# modules/hg/module.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists hg || return 1


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias hg='scm-wrapper.sh hg'


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_XXX_BIN $PATH)


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------


