# modules/template/shell/shrc.sh

# Find location of this script
export METASYSTEM_XXX_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )

export METASYSTEM_XXX_BIN=$METASYSTEM_XXX_ROOT/bin

PATH=$(path_append $METASYSTEM_XXX_BIN $PATH)

