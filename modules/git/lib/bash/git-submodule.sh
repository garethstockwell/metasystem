# git-submodule.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function git_submodule_all_paths()
{
	git submodule --quiet foreach 'echo $path'
}

# Returns true if there is modified content in submodules
function git_submodule_modified()
{
	local sub=$(git ls-files --error-unmatch --stage | grep -E '^160000' | sed -e 's/^.* //' | tr '\n' ' ')
	if [[ -n "$sub" ]]; then
		test -n "$(git status --porcelain -- $sub | grep -E '^[ MARC][MD]')"
	else
		return 0
	fi
}

