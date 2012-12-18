# modules/git/module.sh

GIT_EXE=$(which git)

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function git_current_repo()
{
	local ref=$(git symbolic-ref HEAD 2> /dev/null) || \
	local ref=$(git rev-parse --short HEAD 2> /dev/null) || return
	echo $(git remote -v | cut -d':' -f 2)
}

function git_current_branch()
{
	local ref=$(git symbolic-ref HEAD 2> /dev/null) || \
	local ref=$(git rev-parse --short HEAD 2> /dev/null) || return
	echo ${ref#refs/heads/}
}

function git_remote_repo()
{
	local local_branch=$1
	$GIT_EXE config branch.${local_branch}.remote 2>/dev/null
}

function git_remote_branch()
{
	local local_branch=$1
	local remote_branch=$($GIT_EXE config branch.${local_branch}.merge 2>/dev/null) || return
	echo ${remote_branch#refs/heads/}
}

function git_head()
{
	$GIT_EXE rev-parse HEAD 2>/dev/null
}

function git_root()
{
	$GIT_EXE rev-parse --show-toplevel || echo "."
}


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------


# http://railstips.org/blog/archives/2009/02/02/bedazzle-your-bash-prompt-with-git-info/
# Alternatively, from http://asemanfar.com/Current-Git-Branch-in-Bash-Prompt
# git name-rev HEAD 2> /dev/null | awk "{ print \\$2 }"
function metasystem_git_prompt()
{
	local local_branch=$(git_current_branch) || return
	if [[ -n $local_branch ]]; then
		local content=
		local start=${NAKED_LIGHT_CYAN}
		local end=${NAKED_NO_COLOR}

		if [[ -n $METASYSTEM_ID_GIT ]]; then
			content="${content} ${start}${METASYSTEM_ID_GIT}${end}"
		fi

		local branch=${local_branch}
		local remote_repo=$(git_remote_repo $local_branch)
		if [[ -n $remote_repo ]]; then
			local remote_branch=$(git_remote_branch $local_branch)
			branch="${branch} (${remote_repo}/${remote_branch})"
		fi

		content="${content} ${start}${branch}${end}"

		local head=$(git_head | head -c8)
		if [[ -n $head ]]; then
			content="${content} ${start}$head${end}"
		fi

		local status=
		local status_out=$($GIT_EXE status -unormal 2>/dev/null)

		if [[ $status_out =~ Your\ branch\ is\ ahead ]]; then
			status="${status} ${NAKED_LIGHT_YELLOW}ahead${end}"
		elif [[ $status_out =~ Your\ branch\ is\ behind ]]; then
			status="${status} ${NAKED_LIGHT_YELLOW}behind${end}"
		fi

		if [[ $status_out =~ nothing\ to\ commit ]]; then
			status="${status} ${NAKED_LIGHT_GREEN}clean${end}"
		else
			status="${status}${NAKED_LIGHT_RED}"
			if [[ $status_out =~ Changes\ to\ be\ committed ]]; then
				status="${status} staged"
			fi
			if [[ $status_out =~ Changes\ not\ staged\ for\ commit ]]; then
				status="${status} unstaged"
			fi
			if [[ $status_out =~ Untracked\ files ]]; then
				status="${status} untracked"
			fi
			status="${status}${end}"
		fi

		if [[ -n $status ]]; then
			content="${content}${status}"
		fi

		if [[ -n $content ]]; then
			echo "${start}git:${content}${end}"
		fi
	fi
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_GIT_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_GIT_BIN=$METASYSTEM_GIT_ROOT/bin


#------------------------------------------------------------------------------
# Exported functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias gcd='cd $(git_root)'


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_GIT_BIN $PATH)

metasystem_register_prompt_hook metasystem_git_prompt

