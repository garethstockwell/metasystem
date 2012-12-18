# modules/git/module.sh

#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

GIT_EXE=$(which git)

# http://railstips.org/blog/archives/2009/02/02/bedazzle-your-bash-prompt-with-git-info/
# Alternatively, from http://asemanfar.com/Current-Git-Branch-in-Bash-Prompt
# git name-rev HEAD 2> /dev/null | awk "{ print \\$2 }"
function metasystem_git_prompt()
{
	local content=
	[[ -n $METASYSTEM_ID_GIT ]] && content="${content} id:$METASYSTEM_ID_GIT"
    local ref=$($GIT_EXE symbolic-ref HEAD 2> /dev/null) || return
	[[ -n $ref ]] && content="${content} branch:${ref#refs/heads/}"
    [[ -n $content ]] && echo "${NAKED_LIGHT_RED}git:${content}${NAKED_NO_COLOUR}"
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_GIT_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export METASYSTEM_GIT_BIN=$METASYSTEM_GIT_ROOT/bin


#------------------------------------------------------------------------------
# Exported functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_GIT_BIN $PATH)

metasystem_register_prompt_hook metasystem_git_prompt

