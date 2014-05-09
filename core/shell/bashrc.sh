# bashrc.sh

# bash/zsh compatibility
# Used as e.g. "local ${OVERRIDE_SPECIAL} path=something"
OVERRIDE_SPECIAL=

#------------------------------------------------------------------------------
# Completion
#------------------------------------------------------------------------------

# http://unix.stackexchange.com/questions/4219/how-do-i-get-bash-completion-for-command-aliases
function declare_bash_completion_wrapper()
{
	local function_name="$2"
	local arg_count=$(($#-3))
	local comp_function_name="$1"
	shift 2
	local function="
	function $function_name()
	{
		((COMP_CWORD+=$arg_count))
		COMP_WORDS=( "$@" \${COMP_WORDS[@]:1} )
		"$comp_function_name"
		return 0
	}"
	eval "$function"
}


#------------------------------------------------------------------------------
# Cross-shell rc
#------------------------------------------------------------------------------

source $(dirname ${BASH_SOURCE[0]})/shrc.sh


#------------------------------------------------------------------------------
# Bash feature flags
#------------------------------------------------------------------------------

if [[ $BASH_VERSINFO -ge 4 ]]; then
	METASYSTEM_BASH_ASSOC_ARRAY=yes
	METASYSTEM_BASH_PARAM_SUBST_CASE_MODIFIERS=yes
fi

export METASYSTEM_BASH_ASSOC_ARRAY
export METASYSTEM_BASH_PARAM_SUBST_CASE_MODIFIERS


#------------------------------------------------------------------------------
# Shell options
#------------------------------------------------------------------------------

set -o notify				# Report completed jobs as soon as they finish
set -o noclobber			# Do not overwrite without checking
# set -o xtrace				# Expand arguments - for debugging

shopt -s cmdhist			# Save multiline commands as single history
shopt -s checkwinsize		# Update LINES and COLUMNS after each command

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

set -o ignoreeof            # Cause Ctrl-d not to exit the shell, unless
                            # pressed 10 times


#------------------------------------------------------------------------------
# Command-line completion
#------------------------------------------------------------------------------

[[ -e /etc/bash_completion ]] && source /etc/bash_completion


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

function _metasystem_prompt_update()
{
	PS1=$(_metasystem_prompt)
}

export PROMPT_COMMAND=_metasystem_prompt_update

