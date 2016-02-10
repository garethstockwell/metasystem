# modules/ruby.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists ruby || return 1


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_RUBY_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_RUBY_BIN=$METASYSTEM_RUBY_ROOT/bin


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_RUBY_BIN $PATH)
PATH=$(path_append $HOME/.gem/ruby/1.9.1/bin $PATH)

