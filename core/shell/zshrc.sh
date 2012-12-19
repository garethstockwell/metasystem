# zshrc.sh

# bash/zsh compatibility
# Used as e.g. "local ${OVERRIDE_SPECIAL} path=something"
OVERRIDE_SPECIAL=-h

source $(dirname $0)/shrc.sh

#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

function precmd()
{
	PROMPT=$(_metasystem_prompt)
}

