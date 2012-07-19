# lib/bash/path.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# http://stackoverflow.com/questions/370047/what-is-the-most-elegant-way-to-remove-a-path-from-the-path-variable-in-bash
# http://www.linuxjournal.com/content/remove-path-your-path-variable-0

function path_split()
{
	local replace=$1
	test -z "$replace" && replace="\n"
	shift
	local src="$*"
	local pattern="s/:\([^\\]\)/$replace\1/g"
	echo $src | sed -e $pattern
}

function path_remove()
{
	local element=$1
	shift
	local src="$*"
	path_split '\n' "$src" | grep -v "^$element\$" | tr '\n' ':' | sed 's/:$//'
}

function path_append()
{
	local element=$1
	shift
	local src="$*"
	local path=$(path_remove $element $src)
	test -n "$path" && element=:$element
	echo $path$element
}

function path_append_if_exists()
{
	local element=$1
	shift
	local path="$*"
	test -d "$element" && path=$(path_append $element $path)
	echo $path
}

function path_prepend()
{
	local element=$1
	shift
	local src="$*"
	local path=$(path_remove "$element" $src)
	test -n "$path" && element=$element:
	echo $element$path
}

function path_prepend_if_exists()
{
	local element=$1
	shift
	local path="$*"
	test -d "$element" && path=$(path_prepend $element $path)
	echo $path
}

