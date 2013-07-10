# git.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Returns success if there are staged changes
function git_staged()
{
	test -n "$(git status --porcelain --ignore-submodules | grep -E '^[MARC]')"
}

# Returns success if there are unstaged changes
function git_unstaged()
{
	test -n "$(git status --porcelain --ignore-submodules | grep -E '^[ MARC][MD]')"
}

# Returns success if there are untracked files
function git_untracked()
{
	test -n "$(git status --porcelain | grep -E '^\?\?')"
}

# Returns success if there are unmerged changes
function git_unmerged()
{
	test -n "$(git status --porcelain | grep -E '^(DD|AU|UD|UA|DU|AU|UU)')"
}

# Returns success if there are uncommitted changes
function git_uncommitted()
{
	test -n "$(git status --porcelain | grep -E '^[MADRC]')"
}

# Returns success if there are unpushed changes
function git_unpushed()
{
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

