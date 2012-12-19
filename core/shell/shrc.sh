# shrc.sh

#------------------------------------------------------------------------------
# OS / platform
#------------------------------------------------------------------------------

# TODO: set METASYSTEM_OS_VERSION on Windows
# http://www.windows-commandline.com/2009/01/find-windows-os-version-from-command.html

METASYSTEM_OS=unknown
METASYSTEM_OS_VENDOR=unknown
METASYSTEM_OS_VERSION=unknown
METASYSTEM_PLATFORM=unknown

if [[ -n `uname | grep -i ^cygwin` ]]; then
	METASYSTEM_OS=windows
	METASYSTEM_OS_VENDOR=microsoft
	METASYSTEM_PLATFORM=cygwin
	export CYGWIN_HOME=/cygdrive/c/cygwin
fi

if [[ -n `uname | grep -i ^mingw` ]]; then
	METASYSTEM_OS=windows
	METASYSTEM_OS_VENDOR=microsoft
	METASYSTEM_PLATFORM=mingw
	export MSYS_HOME=/c/MinGW/msys/1.0
	export TERM=msys
fi

if [[ -n `uname | grep -i ^darwin` ]]; then
	METASYSTEM_OS=mac
	METASYSTEM_OS_VENDOR=apple
	METASYSTEM_OS_VERSION=`sw_vers -productVersion`
	METASYSTEM_PLATFORM=unix
fi

if [[ -n `uname | grep -i ^sunos` ]]; then
	METASYSTEM_OS=sunos
	METASYSTEM_OS_VENDOR=sun
	METASYSTEM_OS_VERSION=
	METASYSTEM_PLATFORM=unix
fi

if [[ $METASYSTEM_OS == unknown && -e /etc/issue ]]; then
	METASYSTEM_OS=linux
	METASYSTEM_OS_VENDOR=`cat /etc/issue | awk '{ print $1 }' | tr 'A-Z' 'a-z'`
	METASYSTEM_OS_VERSION=`cat /etc/issue | awk '{ print $2 }' | tr 'A-Z' 'a-z'`
	METASYSTEM_PLATFORM=unix
fi

export METASYSTEM_OS
export METASYSTEM_OS_VENDOR
export METASYSTEM_OS_VERSION
export METASYSTEM_PLATFORM
export METASYSTEM_HOSTNAME=$HOSTNAME


#------------------------------------------------------------------------------
# Home
#------------------------------------------------------------------------------

# Ensure that we start in the home directory
cd $HOME

# Find location of this script
export METASYSTEM_ROOT=$( builtin cd $(dirname ${BASH_SOURCE:-$0})/../.. && pwd )

export METASYSTEM_CORE_ROOT=$METASYSTEM_ROOT/core
export METASYSTEM_CORE_BIN=$METASYSTEM_CORE_ROOT/bin
export METASYSTEM_CORE_LIB=$METASYSTEM_CORE_ROOT/lib
export METASYSTEM_CORE_SHELL=$METASYSTEM_CORE_ROOT/shell
export METASYSTEM_CORE_TEMPLATES=$METASYSTEM_CORE_ROOT/templates

export METASYSTEM_CORE_LIB_BASH=$METASYSTEM_CORE_LIB/bash

if [[ -n $METASYSTEM_LOCAL_ROOT ]]; then
	metasystem_local_root=$METASYSTEM_LOCAL_ROOT
else
	metasystem_local_root=$METASYSTEM_CORE_ROOT/../metasystem-local
fi

if [[ -d $metasystem_local_root ]]; then
	export METASYSTEM_LOCAL_ROOT=$(cd $metasystem_local_root && pwd)
	export METASYSTEM_LOCAL_BIN=$METASYSTEM_LOCAL_ROOT/bin
	export METASYSTEM_LOCAL_LIB=$METASYSTEM_LOCAL_ROOT/lib
	export METASYSTEM_LOCAL_SHELL=$METASYSTEM_LOCAL_ROOT/shell
	export METASYSTEM_LOCAL_TEMPLATES=$METASYSTEM_LOCAL_ROOT/templates
	export METASYSTEM_CORE_CONFIG=$METASYSTEM_LOCAL_ROOT/config

	export METASYSTEM_LOCAL_LIB_BASH=$METASYSTEM_LOCAL_LIB/bash
else
	export METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config
fi


#------------------------------------------------------------------------------
# Config
#------------------------------------------------------------------------------

# Import config
source $METASYSTEM_CORE_SHELL/config.sh


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

# Import utility functions
source $METASYSTEM_CORE_LIB_BASH/utils.sh
source $METASYSTEM_CORE_LIB_BASH/path.sh
source $METASYSTEM_CORE_LIB_BASH/string.sh


#------------------------------------------------------------------------------
# Autoload
#------------------------------------------------------------------------------

for dir in $METASYSTEM_CORE_LIB/autoload \
	       $METASYSTEM_CORE_LIB/autoload/$METASYSTEM_PLATFORM; do
	export FPATH=$dir:$FPATH
	for file in $(find $dir -type f 2>/dev/null); do
		autoload $(basename $file)
	done
done


#------------------------------------------------------------------------------
# Profile
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_SHELL/profile.sh


#------------------------------------------------------------------------------
# Misc setup
#------------------------------------------------------------------------------

# cgrep
# 1;32 = bright green
# See	http://www.termsys.demon.co.uk/vtansi.htm#colors
#		http://www.debian-administration.org/articles/460
export GREP_COLOR='1;32'

# X server forwarding
[[ $METASYSTEM_PLATFORM == cygwin ]] && export DISPLAY=127.0.0.1:0.0

# Git colorizer
export PAGER='less -R'


#------------------------------------------------------------------------------
# Utility functions: window titles
#------------------------------------------------------------------------------

# Function to set window title
function xterm_set_title()
{
	case $TERM in
		*term | rxvt)
			echo -n -e "\033]0;$*\007" ;;
		*)  ;;
	esac
}


#------------------------------------------------------------------------------
# Utility functions: misc
#------------------------------------------------------------------------------

# Empty function
function empty_function()
{
	echo > /dev/null
}


#------------------------------------------------------------------------------
# Apps
#------------------------------------------------------------------------------

[[ $METASYSTEM_PLATFORM == cygwin ]] && _METASYSTEM_APPS=/cygdrive/c/apps
[[ $METASYSTEM_PLATFORM == mingw ]] && _METASYSTEM_APPS=/c/apps
[[ -z $_METASYSTEM_APPS ]] && _METASYSTEM_APPS=~/apps


#------------------------------------------------------------------------------
# Platform
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_SHELL/shrc-$METASYSTEM_PLATFORM.sh
os_rc=$METASYSTEM_CORE_SHELL/shrc-$METASYSTEM_OS.sh
[[ -e $os_rc ]] && source $os_rc
unset os_rc


#------------------------------------------------------------------------------
# Python check
#------------------------------------------------------------------------------

have_python=`which python`


#------------------------------------------------------------------------------
# PATH
#------------------------------------------------------------------------------

PATH=$HOME/bin:$PATH

# Editor
METASYSTEM_EDITOR=vi

# Misc apps
PATH=$(path_prepend_if_exists $_METASYSTEM_APPS/bin $PATH)

# Misc tools
PATH=$METASYSTEM_CORE_BIN:${PATH}

# Templater
PATH=$(path_append_if_exists ~/work/sync/git/templater/bin $PATH)

# stuff
[[ -d $METASYSTEM_CORE_ROOT/../stuff ]] && source $METASYSTEM_CORE_ROOT/../stuff/bashrc-stuff

PATH=$(path_remove '^\.$' $PATH)

[[ -d $VIM_HOME ]] && export METASYSTEM_EDITOR=$(metasystem_nativepath $VIM_HOME/vim.exe)


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

# Enable trusted X forwarding
alias ssh='ssh -Y'
alias scp='scp -2'
alias com='history | grep $1'
alias findproc='ps -ax -o %p%u%c%t | grep -v grep | grep $1'
alias du='du -h'
alias df='df -kh'

alias del='cmd /c del'

alias less='less -x4 -R'	# R is for cgrep

alias ls='ls -hF'
if [[ $METASYSTEM_PLATFORM == mac ]]; then
	alias ls='ls -hFG'		# add colors for filetype recognition
else
	[[ $METASYSTEM_OS != sunos ]] &&\
		alias ls='ls -hF --color'	# add colors for filetype recognition
fi

alias ll='ls -l'			# long listing
alias lx='ls -lXB'			# sort by extension
alias lk='ls -lSr'			# sort by size
alias la='ls -Al'			# show hidden files
alias lr='ls -lR'			# recursive ls
alias lt='ls -ltr'			# sort by date
alias lm='ls -al |more'		# pipe through 'more'
alias tree='tree -Cs'		# nice alternative to 'ls'

alias vi='vim'

alias sync='sync.py'
alias p4='p4.pl'
alias todo='todo.sh'

alias nativepath=metasystem_nativepath
alias npath=metasystem_nativepath
alias unixpath=metasystem_unixpath
alias upath=metasystem_unixpath

alias beep="echo $'\a'"

# Colorising grep
# Reads GREP_COLOR environment variable
# Note: requires 'less -R' to correctly interpret escapes
alias cgrep='grep --color=always'

alias path='path_split \\n $PATH'

# Avoid using the DOS ftp client
[[ $METASYSTEM_PLATFORM == mingw ]] && alias ftp='/bin/ftp.exe'

[[ $METASYSTEM_OS == linux ]] &&\
	alias rdp='metasystem_run_bg xfreerdp -d dir -u $USER -g 1920x1080 -a 32 -x l -o'


#------------------------------------------------------------------------------
# Banner
#------------------------------------------------------------------------------

export _METASYSTEM_RULE='-------------------------------------------------------------------------------'

function _metasystem_print_banner()
{
	echo -e "\n$_METASYSTEM_RULE"
	echo $1
	echo -e "$_METASYSTEM_RULE\n"
}


#------------------------------------------------------------------------------
# System information
#------------------------------------------------------------------------------

echo -e "$_METASYSTEM_RULE\n"
echo "Hostname:   $METASYSTEM_HOSTNAME"
[[ -n $have_python ]] && echo "Domain:     $($METASYSTEM_CORE_BIN/network-info.py domain)"
if [[ $METASYSTEM_OS == linux ]]; then
	echo "IP address: "`ifconfig | grep 'inet addr' | head -n1 | awk ' { print $2 } ' | sed -e 's/addr://'`
else
	echo "IP address: $($METASYSTEM_CORE_BIN/network-info.py ip)"
fi
echo "OS:         $METASYSTEM_OS"
echo "OS vendor:  $METASYSTEM_OS_VENDOR"
echo "OS version: $METASYSTEM_OS_VERSION"
echo "Platform:   $METASYSTEM_PLATFORM"


#------------------------------------------------------------------------------
# dirinfo
#------------------------------------------------------------------------------

function _metasystem_dirinfo_init()
{
	_metasystem_dirinfo_install $*
}

function _metasystem_dirinfo_install()
{
	local force=
	[[ "$1" == "-force" ]] && force=1
	[[ "$1" == "--force" ]] && force=1
	local src=$METASYSTEM_CORE_ROOT/templates/metasystem-dirinfo
	local dst=$PWD/.metasystem-dirinfo
	if [[ -e $dst && -z $force ]]; then
		echo "$PWD/.metasystem-dirinfo already exists"
		echo "Use --force to overwrite it"
	else
		echo "Creating $dst ..."
		rm -f $dst
		subst-vars.sh $src $dst
	fi
}

alias dirinfo-init='_metasystem_dirinfo_init'


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

function metasystem_short_path()
{
	# Shortened path
	# http://lifehacker.com/5167879/cut-the-bash-prompt-down-to-size
	local dir=$1
	dir=`echo $dir | sed -e "s!^$HOME!~!"`
	[[ ${#dir} -gt 50 ]] && dir="${dir:0:22} ... ${dir:${#dir}-23}"
	echo $dir
}

# This is triggered when the directory is changed
function _metasystem_prompt_update_cd()
{
	_metasystem_short_path=$(metasystem_short_path $PWD)
	_metasystem_short_dirinfo_root=
	[[ $METASYSTEM_DIRINFO_ROOT != $HOME ]] &&\
		_metasystem_short_dirinfo_root=$(metasystem_short_path $METASYSTEM_DIRINFO_ROOT)
}

# Called from smartcd scripts
export _metasystem_prompt_update_cd

function _metasystem_prompt_hooks()
{
	echo > /dev/null
}

function metasystem_register_prompt_hook()
{
	local body=$1
	append_to_function _metasystem_prompt_hooks $body
}

function _metasystem_prompt()
{
	# Do this first to ensure we get the correct value of $?
	local rc=$?
	local prompt_rc=
	[[ $rc != 0 ]] && local prompt_rc="${NAKED_LIGHT_PURPLE}$rc ${NAKED_NO_COLOUR}"

	local prompt=

	[[ -n $METASYSTEM_DIRINFO_LABEL ]] &&
		prompt="${prompt}${NAKED_LIGHT_PURPLE}${METASYSTEM_DIRINFO_LABEL}${NAKED_NO_COLOUR} "

	#[[ -n $_metasystem_short_dirinfo_root ]] &&\
	#	prompt="${prompt}${NAKED_LIGHT_CYAN}${_metasystem_short_dirinfo_root}${NAKED_NO_COLOUR} "

	[[ -n $prompt ]] && prompt="${prompt}\n"

	if [[ -n $ZSH_VERSION ]]; then
		local user='%n'
		local time='%D{%H:%M}'
	else
		local user='\u'
		local time='\A'
	fi

	local hostname=$HOSTNAME
	[[ -z $hostname ]] && hostname=$HOST
	[[ -n $METASYSTEM_PROFILE_HOST ]] && hostname=$METASYSTEM_PROFILE_HOST
	prompt="${prompt}${NAKED_LIGHT_BLUE}${user}@${hostname} ${NAKED_LIGHT_YELLOW}${_metasystem_short_path}${NAKED_NO_COLOUR}"

	prompt="${prompt}${_prompt_tools}${_prompt_ids}"

	local prompt_hooks="$(_metasystem_prompt_hooks)"
	[[ -n $prompt_hooks ]] && prompt="${prompt}\n${prompt_hooks}"

	local prompt_time="${NAKED_LIGHT_YELLOW}${time}${NAKED_NO_COLOUR}"
	echo "\n${prompt}\n${prompt_rc}${prompt_time} \$ "
}



