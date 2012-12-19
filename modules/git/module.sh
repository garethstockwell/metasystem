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
	$GIT_EXE rev-parse --show-toplevel
}

function git_grep()
{
	local path=$1
	shift
	grep "$@" $(find $path -type f | grep -v .git)
}

function gcd()
{
	local root=$(git_root)
	[[ -n $root ]] && cd $root
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

		local lstatus=
		local status_out="$($GIT_EXE status -unormal 2>/dev/null)"

		if [[ $status_out =~ Your\ branch\ is\ ahead ]]; then
			lstatus="${lstatus} ${NAKED_LIGHT_YELLOW}ahead${end}"
		elif [[ $status_out =~ Your\ branch\ is\ behind ]]; then
			lstatus="${lstatus} ${NAKED_LIGHT_YELLOW}behind${end}"
		fi

		if [[ $status_out =~ nothing\ to\ commit ]]; then
			lstatus="${lstatus} ${NAKED_LIGHT_GREEN}clean${end}"
		else
			lstatus="${lstatus}${NAKED_LIGHT_RED}"
			if [[ $status_out =~ Changes\ to\ be\ committed ]]; then
				lstatus="${lstatus} staged"
			fi
			if [[ $status_out =~ Changes\ not\ staged\ for\ commit ]]; then
				lstatus="${lstatus} unstaged"
			fi
			if [[ $status_out =~ Untracked\ files ]]; then
				lstatus="${lstatus} untracked"
			fi
			lstatus="${lstatus}${end}"
		fi

		if [[ -n "$lstatus" ]]; then
			content="${content}${lstatus}"
		fi

		if [[ -n "$content" ]]; then
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

