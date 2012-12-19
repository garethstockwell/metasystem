# lib/bash/list.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function list_append()
{
	local element=$1
	shift
	local list="$*"
	test -n "$list" && element=" $element"
	echo $list$element
}

function list_remove()
{
	local element=$1
    shift
    local list="$*"
    echo $list | sed -e 's/ /\n/g' | grep -v "$element" | tr '\n' ' ' | sed 's/ $//'
}

# Checks whether a given element occurs in a space-separated list
# Usage: <element> <list>
# Returns: '1' or an empty string
function list_contains()
{
    local element=$1
    shift
    local list="$*"
    local result=
    for x in $list
    do
        [[ "$x" == "$element" ]] && result=1
    done
    echo $result
}

function list_pipe_separated()
{
    local list="$*"
    echo $list | sed -e 's/ /|/g'
}

