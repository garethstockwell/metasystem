# zshrc.sh

# bash/zsh compatibility
# Used as e.g. "local ${OVERRIDE_SPECIAL} path=something"
OVERRIDE_SPECIAL=-h

source $(dirname $0)/shrc.sh


#------------------------------------------------------------------------------
# Shell options
#------------------------------------------------------------------------------

setopt shwordsplit


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

function precmd()
{
	PROMPT=$(_metasystem_prompt)
}



