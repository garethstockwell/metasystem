# modules/git/module.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists git || return 1


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function git_root()
{
	$GIT_EXE rev-parse --show-toplevel
}

function git_in_repo()
{
	git_root >/dev/null 2>/dev/null || return 1
	return 0
}

function git_current_repo()
{
	git_in_repo || return 1
	local ref="$(git symbolic-ref HEAD 2> /dev/null)" || \
	local ref="$(git rev-parse --short HEAD 2> /dev/null)" || return
	echo $(git remote -v | cut -d':' -f 2)
}

function git_current_branch()
{
	git_in_repo || return 1
	local ref="$(git symbolic-ref HEAD 2> /dev/null)" || \
	local ref="$(git rev-parse --short HEAD 2> /dev/null)" || return
	echo ${ref#refs/heads/}
}

function git_remote_repo()
{
	git_in_repo || return 1
	local local_branch=$1
	[[ -n ${local_branch} ]] || local_branch=$(git_current_branch)
	$GIT_EXE config branch.${local_branch}.remote 2>/dev/null
}

function git_remote_branch()
{
	git_in_repo || return 1
	local local_branch=$1
	[[ -n ${local_branch} ]] || local_branch=$(git_current_branch)
	local remote_branch="$($GIT_EXE config branch.${local_branch}.merge 2>/dev/null)" || return
	echo ${remote_branch#refs/heads/}
}

function git_head()
{
	git_in_repo || return 1
	$GIT_EXE rev-parse HEAD 2>/dev/null
}

# Returns success if there are staged changes
function git_staged()
{
	git_in_repo || return 1
	test -n "$(git status --porcelain --ignore-submodules | grep -E '^[MARC]')"
}

# Returns success if there are unstaged changes
function git_unstaged()
{
	git_in_repo || return 1
	test -n "$(git status --porcelain --ignore-submodules | grep -E '^[ MARC][MD]')"
}

# Returns success if there are untracked files
function git_untracked()
{
	git_in_repo || return 1
	test -n "$(git status --porcelain | grep -E '^\?\?')"
}

# Returns success if there are unmerged changes
function git_unmerged()
{
	git_in_repo || return 1
	test -n "$(git status --porcelain | grep -E '^(DD|AU|UD|UA|DU|AU|UU)')"
}

# Returns success if there are uncommitted changes
function git_uncommitted()
{
	git_in_repo || return 1
	test -n "$(git status --porcelain | grep -E '^[MADRC]')"
}

# Returns success if there are unpushed changes
function git_unpushed()
{
	git_in_repo || return 1
	local message=
	local output=$(git branch --no-color -vv 2> /dev/null)
	while read line; do
		branch=`expr "$line" : '\** *\([^ ]*\)'`
		remote=`expr "$line" : '.*\[\(.*\)\]'` || continue
		status=`expr "$remote" : '.*: ahead \(.*\)'` || continue
		[[ -n $message ]] && message=$(echo -e "$message\n")
		message="${message}Branch '$branch' is ahead $status commit(s)"
		result=0
	done <<< "$output"
	[[ $result == 0 ]] && echo $message
	return $result
}

function git_grep()
{
	git_in_repo || return 1
	local path=$1
	shift
	grep "$@" $(find $path ! -path "*/.git/*" -type f)
}

function metasystem_grep()
{
	git_grep $METASYSTEM_ROOT "$@"
	if [[ -n $METASYSTEM_LOCAL_ROOT && -d $METASYSTEM_LOCAL_ROOT ]]; then
		git_grep $METASYSTEM_LOCAL_ROOT "$@"
	fi
}

function gcd()
{
	local root="$(git_root)"
	[[ -n $root ]] && cd $root
}

function metasystem_install_git_hooks()
{
	local hook_dir=.git/hooks
	if [[ -d $hook_dir ]]; then
		builtin cd $hook_dir
		for sample in $('ls' *.sample); do
			dst=${sample//.sample/}
			src=$METASYSTEM_GIT_ROOT/hooks/$dst
			[[ -e $src ]] && rm -f $dst && ln -s $src $dst
		done
		builtin cd ../..
	else
		echo "Error: .git/hooks not found" >&2
		return 1
	fi
}

function git_diff()
{
	git diff --no-index "$@"
}

alias diff=git_diff


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_GIT_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_GIT_BIN=$METASYSTEM_GIT_ROOT/bin

export PAGER='less -R'


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias git='scm-wrapper.sh git'
alias gcd='cd $(git_root)'


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

if [[ $METASYSTEM_OS != windows ]]; then

# http://railstips.org/blog/archives/2009/02/02/bedazzle-your-bash-prompt-with-git-info/
# Alternatively, from http://asemanfar.com/Current-Git-Branch-in-Bash-Prompt
# git name-rev HEAD 2> /dev/null | awk "{ print \\$2 }"
function _metasystem_hook_git_prompt()
{
	local local_branch="$(git_current_branch)" || return
	if [[ -n $local_branch ]]; then
		local content=
		local start=${LIGHT_CYAN}
		local end=${NO_COLOR}

		if [[ -n $METASYSTEM_ID_GIT ]]; then
			content="${content} ${start}${METASYSTEM_ID_GIT}${end}"
		fi

		local branch=${local_branch}
		local remote_repo="$(git_remote_repo $local_branch)"
		if [[ -n $remote_repo ]]; then
			local remote_branch="$(git_remote_branch $local_branch)"
			branch="${branch} (${remote_repo}/${remote_branch})"
		fi

		content="${content} ${start}${branch}${end}"

		local head="$(git_head | head -c8)"
		if [[ -n $head ]]; then
			content="${content} ${start}$head${end}"
		fi

		local lstatus=
		local status_out="$($GIT_EXE status -unormal 2>/dev/null)"

		if [[ $status_out =~ Your\ branch\ is\ ahead ]]; then
			lstatus="${lstatus} ${LIGHT_YELLOW}ahead${end}"
		elif [[ $status_out =~ Your\ branch\ is\ behind ]]; then
			lstatus="${lstatus} ${LIGHT_YELLOW}behind${end}"
		fi

		if [[ $status_out =~ nothing\ to\ commit ]]; then
			lstatus="${lstatus} ${LIGHT_GREEN}clean${end}"
		else
			lstatus="${lstatus}${LIGHT_RED}"
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

fi # !windows


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

GIT_EXE=$(which git)
PATH=$(path_append $METASYSTEM_GIT_BIN $PATH)

_metasystem_dotfile_register git gitconfig
_metasystem_dotfile_register git gitconfig-local

