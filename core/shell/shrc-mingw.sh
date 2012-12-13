# shrc-mingw.sh

#------------------------------------------------------------------------------
# Path handling
#------------------------------------------------------------------------------

function metasystem_drivepath()
{
	local letter=$(metasystem_driveletter $1)
	[[ -n $letter ]] && echo /$letter
}

function metasystem_driveletter()
{
	echo $1 | sed -e 's/\/\([a-zA-Z]\).*/\1/'
}

function metasystem_nativepath()
{
	echo $1 | sed -e 's/^\/\([a-zA-Z]\)\//\1:\//'
}

function metasystem_unixpath()
{
	echo $1 | sed -e 's/^\([a-zA-Z]\):/\/\1/' -e 's/\\/\//g'
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

function metasystem_unixpathlist()
{
	echo ";$*" | sed \
		-e 's/;\([a-zA-Z]\):[\\\/]/:\/\1\//g' \
		-e 's/^://'
}

function metasystem_path_remove_mingw()
{
	local path=$PATH
	path=$(path_remove /usr/local/bin $path)
	path=$(path_remove /mingw/bin $path)
	path=$(path_remove /bin $path)
	path=$(path_remove $MINGW_HOME/bin $path)
	path=$(path_remove $(npath $MINGW_HOME/bin) $path)
	echo $path
}

export -f metasystem_nativepathlist

# Obsolete
#export -f metasystem_path_remove_mingw

PATH=$PATH:$METASYSTEM_CORE_BIN/mingw
