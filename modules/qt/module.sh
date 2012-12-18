# modules/qt/module.sh

#------------------------------------------------------------------------------
# Cross-platform functions
#------------------------------------------------------------------------------

function _metasystem_set_qtdirs()
{
	local build_dir=$1
	local source_dir=$2
	local old_build_dir=$QT_BUILD_DIR
	_metasystem_do_set_projectdirs qt "$build_dir" "$source_dir"
	export QT_BUILD_DIR=$build_dir
	export QT_SOURCE_DIR=$source_dir
	if [[ $_metasystem_projectdirs_updated == 1 ]]; then
		if [[ -n $old_build_dir ]]; then
			PATH=$(path_remove $old_build_dir/bin $PATH)
			export PATH=$(path_remove $old_build_dir/lib $PATH)
			export LD_LIBRARY_PATH=$(path_remove $old_build_dir/lib $LD_LIBRARY_PATH)
		fi
		if [[ -n $QT_BUILD_DIR ]]; then
			PATH=$(path_prepend $QT_BUILD_DIR/lib $PATH)
			export PATH=$(path_prepend $QT_BUILD_DIR/bin $PATH)
			export LD_LIBRARY_PATH=$(path_prepend $QT_BUILD_DIR/lib $LD_LIBRARY_PATH)
		fi
	fi
}

function _metasystem_qt_cd_build()
{
	[[ -n $QT_BUILD_DIR ]] && metasystem_cd $QT_BUILD_DIR/$*
}

function _metasystem_qt_cd_source()
{
	[[ -n $QT_SOURCE_DIR ]] && metasystem_cd $QT_SOURCE_DIR/$*
}

rename_function _metasystem_set_projectdirs _metasystem_do_set_projectdirs

function _metasystem_set_projectdirs()
{
	local project=$1
	local build_dir=$2
	local source_dir=$3

	if [[ -n $METASYSTEM_QT_ROOT ]]; then
		if [[ $project == qt ]]; then
			_metasystem_set_qtdirs "$build_dir" "$source_dir"
		else
			if [[ $project == qtmobility ]]; then
				_metasystem_export QTMOBILITY_BUILD_DIR=$build_dir
				_metasystem_export QTMOBILITY_SOURCE_DIR=$source_dir
			fi
		fi
	fi

	_metasystem_do_set_projectdirs $project "$build_dir" "$source_dir"
}

alias qcdb='_metasystem_qt_cd_build'
alias qcds='_metasystem_qt_cd_source'
alias qcd='qcdb'


#------------------------------------------------------------------------------
# Unix functions
#------------------------------------------------------------------------------

[[ $METASYSTEM_PLATFORM == unix ]] && alias qtcreator="metasystem_run_bg $(which qtcreator)"


#------------------------------------------------------------------------------
# Windows functions
#------------------------------------------------------------------------------

if [[ $METASYSTEM_PLATFORM == windows ]]; then
	_metasystem_wrap_native qmake jom

	QT_DEFAULT_NATIVE_BUILD_DIR=/c/apps/qtsdk/Desktop/Qt/4.8.0/msvc2010

	function qtnativebindir()
	{
		if [ -z "$QT_NATIVE_BUILD_DIR" ]
		then
			echo "\$QT_NATIVE_BUILD_DIR not defined" >&2
			echo "Defaulting to $QT_DEFAULT_NATIVE_BUILD_DIR" >&2
			echo $QT_DEFAULT_NATIVE_BUILD_DIR/bin
		else
			echo "\$QT_NATIVE_BUILD_DIR = $QT_NATIVE_BUILD_DIR" >&2
			echo $QT_NATIVE_BUILD_DIR/bin
		fi
	}

	function qtcreator()
	{
		echo -e "Launching QtCreator ..."
		# QtCreator does some pretty naieve parsing of the system environment,
		# so we need to unset all shell functions before starting it
		PATH=$QT_CREATOR_DIR/bin:$QT_CREATOR_DIR/lib:$PATH \
			winwrapper-unset-functions.sh $QT_CREATOR_DIR/bin/qtcreator.exe $* &
	}

	function launch_muxcons()
	{
		PATH=$(path_prepend $(qtnativebindir) $PATH) \
			$QT_WIN32_DIR/hg/muxcons/src/release/muxcons.exe $* &
	}

	function launch_muxrun()
	{
		PATH=$(path_prepend $(qtnativebindir) $PATH) \
			$QT_WIN32_DIR/hg/muxcons/muxrun/release/muxrun.exe $*
	}

	export -f qtcreator

	alias qmake='qtwrapper qmake'
fi


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_QT_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export METASYSTEM_QT_BIN=$METASYSTEM_QT_ROOT/bin
export METASYSTEM_QT_LIB=$METASYSTEM_QT_ROOT/lib

export QTSDK=$_METASYSTEM_APPS/qtsdk
export QT_CREATOR_DIR=$QTSDK/QtCreator
export QT_DEFAULT_NATIVE_BUILD_DIR


#------------------------------------------------------------------------------
# Exported functions
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_QT_BIN $PATH)

