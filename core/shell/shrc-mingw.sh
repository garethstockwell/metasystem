# shrc-mingw.sh

#------------------------------------------------------------------------------
# Path handling
#------------------------------------------------------------------------------

function metasystem_path_remove_mingw()
{
	local lpath=$PATH
	lpath=$(path_remove /usr/local/bin $lpath)
	lpath=$(path_remove /mingw/bin $lpath)
	lpath=$(path_remove /bin $lpath)
	lpath=$(path_remove $MINGW_HOME/bin $lpath)
	lpath=$(path_remove $(nlpath $MINGW_HOME/bin) $lpath)
	echo $lpath
}

PATH=$PATH:$METASYSTEM_CORE_BIN/mingw

