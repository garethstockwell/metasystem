# modules/docker.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists docker || return 1


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_DOCKER_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_DOCKER_BIN=$METASYSTEM_DOCKER_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_DOCKER_BIN $PATH)
echo "*** PATH:"
path

