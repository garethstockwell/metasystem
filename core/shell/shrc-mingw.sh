# shrc-mingw.sh

#------------------------------------------------------------------------------
# Path handling
#------------------------------------------------------------------------------

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

PATH=$PATH:$METASYSTEM_CORE_BIN/mingw

