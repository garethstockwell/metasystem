#!/usr/bin/env bash

# Wrapper script for SCM tools
# For actions which write to a local repo, the script first dynamically
# generates the config file, using the ID currently specified by metasystem
# environment variables.

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

orig_pwd=$(pwd)

script=$0
builtin cd $(dirname "$script")
script=$(basename "$script")

# Iterate down a possible chain of symlinks
while [[ -L $script ]]; do
	script=$(readlink "$script")
	builtin cd $(dirname "$script")
	script=$(basename "$script")
done

SCRIPT_DIR=$(pwd -P)
builtin cd $orig_pwd

[[ -z $METASYSTEM_CORE_LIB ]] && export METASYSTEM_CORE_LIB=$SCRIPT_DIR/../lib
source $METASYSTEM_CORE_LIB_BASH/utils.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

VALID_TOOLS='git hg'

# Words listed below are the commands for each SCM tool which write to the local repo.

WRITE_ACTIONS_GIT='
am
cherry-pick
commit
config
gc
merge
pull
rebase
revert
tag
write-config
'

WRITE_ACTIONS_HG='
backout
branch
commit
import
merge
pull
resolve
revert
rollback
tag
write-config
'

#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

arg_tool=
arg_action=
arg_options=

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
    echo -e "\nError: $*"
    if [ "$opt_dryrun" != yes ]
    then
        exit 1
    fi
}

function usage_error()
{
    echo -e "Error: $*\n"
    print_usage
    exit 1
}

function print_usage()
{
    cat << EOF
SCM wrapper script

Usage: $0 <tool> [args]

Arguments:
    tool                    SCM tool [$(list_pipe_separated $VALID_TOOLS)]

EOF
}

function parse_command_line()
{
	[[ -z "$1" ]] && usage_error "No SCM tool specified"
	arg_tool=$1
	[[ -z $(list_contains $arg_tool $VALID_TOOLS) ]] && usage_error "Invalid tool"
	arg_action=$2
}

function generate_config()
{
	local tool_uc=$(echo $arg_tool | tr 'a-z' 'A-Z')
	local write_action_var=WRITE_ACTIONS_${tool_uc}
	local write_actions=$(eval echo \$$write_action_var)
	local action=$arg_action

	if [[ $arg_tool == git ]]; then
		local action_alias=$(\git config --get alias.$action)
		[[ -z $action_alias ]] || action=$action_alias
	fi

	if [[ -n $action && -n $(list_contains $action $write_actions) ]]; then
		local id_var=METASYSTEM_ID_${tool_uc}
		local id=$(eval echo \$$id_var)
		echo -e "\nGenerating config file for $arg_tool with ID '$id'\n"
		metasystem-id.py --quiet generate --type $arg_tool
	fi
}

function execute_tool()
{
	"$@"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line "$@"
generate_config
if [[ $arg_action != write-config ]]; then
	execute_tool "$@"
fi

