# lib/bash/path.sh

#------------------------------------------------------------------------------
# Cross-platform functions
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
	local list=$(path_remove $element $src)
	test -n "$list" && element=:$element
	echo $list$element
}

function path_append_if_exists()
{
	local element=$1
	shift
	local list="$*"
	test -d "$element" && list=$(path_append $element $list)
	echo $list
}

function path_prepend()
{
	local element=$1
	shift
	local src="$*"
	local list=$(path_remove "$element" $src)
	test -n "$list" && element=$element:
	echo $element$list
}

function path_prepend_if_exists()
{
	local element=$1
	shift
	local list="$*"
	test -d "$element" && list=$(path_prepend $element $list)
	echo $list
}

function path_shorten()
{
	# Shortened path
	# http://lifehacker.com/5167879/cut-the-bash-prompt-down-to-size
	local dir=$1
	dir=`echo $dir | sed -e "s!^$HOME!~!"`
	[[ ${#dir} -gt 50 ]] && dir="${dir:0:22} ... ${dir:${#dir}-23}"
	echo $dir
}

function path_perms()
{
	# http://code.google.com/p/git-osx-installer/issues/detail?id=53
	# http://stackoverflow.com/questions/7997700/git-aliases-causing-permission-denied-error
	local path="$@"
	[[ -z $path ]] && path=$PATH
	echo $path | tr ':' '\n' |xargs ls -ld
}

function path_remove_invalid()
{
	# http://stackoverflow.com/questions/7997700/git-aliases-causing-permission-denied-error
	PATH=$(for d in ${PATH//:/ }; do [ -x $d ] && printf "$d\n"; done | uniq | tr '\12' ':')
	export PATH=${PATH%?}
}


#------------------------------------------------------------------------------
# unix functions
#------------------------------------------------------------------------------

if [[ $METASYSTEM_PLATFORM == unix ]]; then

function metasystem_unixpath()
{
	echo $1
}

function metasystem_nativepath()
{
	echo $1
}

fi


#------------------------------------------------------------------------------
# cygwin functions
#------------------------------------------------------------------------------

if [[ $METASYSTEM_PLATFORM == cygwin ]]; then

function metasystem_unixpath()
{
	if [[ -n $1 ]]; then
		cygpath $1
	fi
}

function metasystem_nativepath()
{
	if [[ -n $1 ]]; then
		cygpath -w $1
	fi
}

function metasystem_driveletter()
{
	echo $1 | sed -e 's/\/cygdrive\/\([a-z]\).*/\1/'
}

function metasystem_drivepath()
{
	local letter=$(metasystem_driveletter $1)
	[[ -n $letter ]] && echo /cygdrive/$letter
}

fi


#------------------------------------------------------------------------------
# mingw functions
#------------------------------------------------------------------------------

if [[ $METASYSTEM_PLATFORM == mingw ]]; then

function metasystem_unixpath()
{
	echo $1 | sed -e 's/^\([a-zA-Z]\):/\/\1/' -e 's/\\/\//g'
}

function metasystem_nativepath()
{
	echo $1 | sed -e 's/^\/\([a-zA-Z]\)\//\1:\//'
}

function metasystem_unixpathlist()
{
	echo ";$*" | sed \
		-e 's/;\([a-zA-Z]\):[\\\/]/:\/\1\//g' \
		-e 's/^://'
}

function metasystem_nativepathlist()
{
	echo ":$*" | sed \
				-e 's/\\/\//g' \
				-e 's/:/;/g' \
				-e 's/;\([a-zA-Z]\);\//;\1:\//g' \
				-e 's/;\/\([a-zA-Z]\)\//;\1:\//g' \
				-e 's/^;//' \
				-e 's/\//\\/g'
}

fi

