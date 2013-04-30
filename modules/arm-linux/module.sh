# modules/arm-linux.sh

#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_ARM_LINUX_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_ARM_LINUX_BIN=$METASYSTEM_ARM_LINUX_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_ARM_LINUX_BIN $PATH)

