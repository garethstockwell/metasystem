# shrc-win.sh

#------------------------------------------------------------------------------
# PATH
#------------------------------------------------------------------------------

# AESS tools
PATH=$(path_append_if_exists /c/apps/aess $PATH)

# GIT
PATH=$(path_append_if_exists $_METASYSTEM_APPS/git/bin $PATH)

# gvim
VIM_HOME=$_METASYSTEM_APPS/vim/vim72
if [[ -d $VIM_HOME ]]; then
	PATH=$(path_prepend $VIM_HOME $PATH)
else
	VIM_HOME=$_METASYSTEM_APPS/vim/vim73
	PATH=$(path_prepend_if_exists $VIM_HOME $PATH)
fi

# 7-zip
PATH=$(path_prepend_if_exists $_METASYSTEM_APPS/7-zip $PATH)

# perl
PERL_HOME=$_METASYSTEM_APPS/activestate/perl/5.10.1.1007
[[ ! -d $PERL_HOME ]] && PERL_HOME=$_METASYSTEM_APPS/activestate/perl/5.12.4
[[ ! -d $PERL_HOME ]] && PERL_HOME=$_METASYSTEM_APPS/activestate/perl/5.12.3
[[ ! -d $PERL_HOME ]] && PERL_HOME=$_METASYSTEM_APPS/activestate/perl/5.8
[[ ! -d $PERL_HOME ]] && PERL_HOME=$_METASYSTEM_APPS/strawberryperl/5.12.2.0-portable/perl
[[ ! -d $PERL_HOME ]] && PERL_HOME=$_METASYSTEM_APPS/strawberryperl/5.12.2.0/perl
PATH=$(path_prepend_if_exists $PERL_HOME/bin $PATH)
export PERL5LIB=$PERL_HOME/site/lib

# python
export PYTHON26DIR=$_METASYSTEM_APPS/python/2.6.6
[[ ! -d $PYTHON26DIR ]] && PYTHON27DIR=$_METASYSTEM_APPS/python/2.6.6.15-x86
export PYTHON27DIR=$_METASYSTEM_APPS/python/2.7
[[ ! -d $PYTHON27DIR ]] && PYTHON27DIR=$_METASYSTEM_APPS/python/2.7.2
[[ ! -d $PYTHON27DIR ]] && PYTHON27DIR=$_METASYSTEM_APPS/python/2.7.1
PATH=$(path_append_if_exists $PYTHON27DIR $PATH)


#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

_metasystem_drive=


#------------------------------------------------------------------------------
# Wrapping native tools
#------------------------------------------------------------------------------

function _metasystem_wrap_native()
{
	local tool
	for tool in $*; do
		alias $tool="winwrapper $tool"
	done
}


#------------------------------------------------------------------------------
# Misc
#------------------------------------------------------------------------------

function killall()
{
	local name=$1
	for pid in `ps -u $(whoami) | grep $name | awk '{ print $1 }'`; do
		kill -9 $pid
	done
}


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

# Remove suffixes from scripts
alias subst-drives='subst-drives.sh'

function metasystem_windows_explorer()
{
	local path=.
	if [[ -n $1 ]]; then
		path=$(metasystem_nativepath $1)
		path=${path//\//\\}
	fi
	explorer.exe $path &
}

alias explorer=metasystem_windows_explorer

