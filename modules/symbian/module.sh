# modules/symbian/module.sh

#------------------------------------------------------------------------------
# Cross-platform functions
#------------------------------------------------------------------------------

function _metasystem_check_epocroot()
{
	if [[ -d $METASYSTEM_DIRINFO_ROOT/epoc32 ]]; then
		EPOCROOT=$METASYSTEM_DIRINFO_ROOT/
		PATH=$(path_prepend_epoc)
		[[ $METASYSTEM_OS == windows &&\
		   $METASYSTEM_DIRINFO_ROOT == $(metasystem_drivepath $METASYSTEM_DIRINFO_ROOT) ]] &&\
			EPOCROOT=\\
		echo -e "${NAKED_LIGHT_RED}epoc: $EPOCROOT${NAKED_NO_COLOUR}"
	else
		[[ -n $EPOCROOT ]] && PATH=$(path_remove_epoc)
		EPOCROOT=
	fi
	[[ -n $QT_BUILD_DIR ]] && PATH=$(path_prepend $QT_BUILD_DIR/bin $PATH)
	export EPOCROOT
	export PATH
}

function metasystem_cd_epocroot()
{
	[[ -n $EPOCROOT ]] && metasystem_cd $EPOCROOT
}

function path_prepend_epoc()
{
	local path=$PATH
	if [[ $METASYSTEM_PLATFORM == mingw ]]; then
		path=$(path_prepend $PERL_HOME/bin $path)
		path=$(path_prepend $EPOCROOT/epoc32/gcc/bin $path)
	fi
	path=$(path_prepend $EPOCROOT/epoc32/tools $path)
	echo $path
}

function path_remove_epoc()
{
	local path=$PATH
	path=$(path_remove $EPOCROOT/epoc32/tools $path)
	path=$(path_remove $EPOCROOT/epoc32/gcc/bin $path)
	echo $path
}

alias ecd='metasystem_cd_epocroot'
alias sf-downloadkit='$SF_TOOLS_DIR/downloadkit/downloadkit.py --user $SF_USERNAME'
alias epocroot='echo $EPOCROOT'

alias si=symbian-install.sh
alias sr=symbian-runonphone.sh


#------------------------------------------------------------------------------
# Windows functions
#------------------------------------------------------------------------------

if [[ $METASYSTEM_PLATFORM == windows ]]; then
	_metasystem_wrap_native devices epoc bldmake abld sbs rom rombuild \
							rofsbuild buildrom makesis maksym petran bmconv \
							rcomp link

	function metasystem_imaker()
	{
		# imaker requires Python 2.6
		local epocroot=$EPOCROOT
		[[ $epocroot == \\ ]] && epocroot=$(metasystem_driveletter $PWD):
		PATH=$PYTHON26DIR:$PATH PYTHONPATH=$PYTHON26DIR/Lib \
			 winwrapper $epocroot/epoc32/tools/imaker $*
	}
	export -f metasystem_imaker
	alias imaker=metasystem_imaker

# Utility functions for accessing emulator log

	function winlog()
	{
		cat $HOME/Local\ Settings/Temp/epocwind.out
	}

	function twinlog()
	{
		/usr/bin/tail -f $HOME/Local\ Settings/Temp/epocwind.out
	}

	alias carbide-2.7='metasystem_run_bg $_METASYSTEM_APPS/carbide/2.7/Carbide.c++.2.7.exe'
	alias carbide-3.0='metasystem_run_bg $_METASYSTEM_APPS/carbide/3.0/Carbide.c++.3.0.exe'
	alias carbide-3.4='metasystem_run_bg $_METASYSTEM_APPS/carbide/Carbide.c++.3.4.exe'

	alias carbide=carbide-3.4
fi


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_SYMBIAN_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_SYMBIAN_BIN=$METASYSTEM_SYMBIAN_ROOT/bin

export SF_TOOLS_DIR=~/work/sync/hg/sf/oss/MCL/sftools/fbf/utilities


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_hook_symbian_prompt()
{
	[[ -n $EPOCROOT ]] &&\
		echo "${LIGHT_RED}epoc: $EPOCROOT${NO_COLOUR}"
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_SYMBIAN_BIN $PATH)

