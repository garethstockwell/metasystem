# shrc.sh

#==============================================================================
# Core setup 1/2
#==============================================================================

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
export METASYSTEM_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )

export METASYSTEM_CORE_ROOT=$METASYSTEM_ROOT/core
export METASYSTEM_CORE_BIN=$METASYSTEM_CORE_ROOT/bin
export METASYSTEM_CORE_LIB=$METASYSTEM_CORE_ROOT/lib
export METASYSTEM_CORE_SHELL=$METASYSTEM_CORE_ROOT/shell
export METASYSTEM_CORE_TEMPLATES=$METASYSTEM_CORE_ROOT/templates

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
else
	export METASYSTEM_CORE_CONFIG=$METASYSTEM_CORE_TEMPLATES/local/config
fi

# Import utility functions
source $METASYSTEM_CORE_LIB/bash/utils.sh
source $METASYSTEM_CORE_LIB/bash/path.sh
source $METASYSTEM_CORE_LIB/bash/string.sh


#------------------------------------------------------------------------------
# Profile
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_SHELL/profile.sh


#------------------------------------------------------------------------------
# Bash feature flags
#------------------------------------------------------------------------------

if [[ $BASH_VERSINFO -ge 4 ]]; then
	METASYSTEM_BASH_ASSOC_ARRAY=yes
	METASYSTEM_BASH_PARAM_SUBST_CASE_MODIFIERS=yes
fi

export METASYSTEM_BASH_ASSOC_ARRAY
export METASYSTEM_BASH_PARAM_SUBST_CASE_MODIFIERS


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
# Utility functions: misc
#------------------------------------------------------------------------------

# Function to set window title
function xtitle()
{
	case $TERM in
		*term | rxvt)
			echo -n -e "\033]0;$*\007" ;;
		*)  ;;
	esac
}

# Empty function
function empty_function()
{
	echo > /dev/null
}

function metasystem_run_bg()
{
	local args=
	local background=1
	for token in "$@"; do
		case $token in
			-fg | --fg | -foreground | --foreground)
				background=
				;;
			-bg | --bg | -background | --background)
				background=1
				;;
			*)
				[[ -n $args ]] && args="$args "
				args="$args$token"
				;;
		esac
	done
	if [[ -n $background ]]; then
		echo "Launching '$args' in background ..."
		nohup $args 1>/dev/null 2>/dev/null &
	else
		$args
	fi
}

export -f metasystem_run_bg


#------------------------------------------------------------------------------
# METASYSTEM_APPS
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

function metasystem_assert_os()
{
	# Prevent sbs from bombing out...
	local x=Error
	if [[ -n $1 && $METASYSTEM_OS != $1 ]]; then
		if [[ -z $2 ]]; then
			echo "$x: this program can only be run on OS '$1'"
		else
			echo "$x: program '$2' can only be run on OS '$1'"
		fi
		exit 1
	fi
}

function metasystem_assert_platform()
{
	# Prevent sbs from bombing out...
	local x=Error
	if [[ -n $1 && $METASYSTEM_PLATFORM != $1 ]]; then
		if [[ -z $2 ]]; then
			echo "$x: this program can only be run on platform '$1'"
		else
			echo "$x: program '$2' can only be run on platform '$1'"
		fi
		exit 1
	fi
}

export -f metasystem_nativepath
export -f metasystem_unixpath
export -f metasystem_assert_os
export -f metasystem_assert_platform

if [[ $METASYSTEM_OS == windows ]]; then
	export -f metasystem_driveletter
	export -f metasystem_drivepath
fi


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

# Raptor
[[ -n $SBS_HOME ]] && PATH=$PATH:$(metasystem_unixpath $SBS_HOME)/bin


#------------------------------------------------------------------------------
# Shell options
#------------------------------------------------------------------------------

set -o notify				# Report completed jobs as soon as they finish
set -o noclobber			# Do not overwrite without checking
# set -o xtrace				# Expand arguments - for debugging

shopt -s cmdhist			# Save multiline commands as single history
shopt -s checkwinsize		# Update LINES and COLUMNS after each command

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend


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
# TODO
#------------------------------------------------------------------------------

function _metasystem_todo()
{
	local todo_dir=~/work/sync/unison/todo
	chmod -R 700 $todo_dir
	todo.sh $*
}

export -f _metasystem_todo
alias todo=_metasystem_todo

function _metasystem_todo_complete()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    COMMANDS="add a addto addm append app archive command del  \
              rm depri dp do help list ls listall lsa listcon  \
              lsc listfile lf listpri lsp listproj lsproj move \
              mv prepend prep pri p replace report"

    # Add custom commands from add-ons, if installed.
    COMMANDS="$COMMANDS $('ls' ${TODO_ACTIONS_DIR:-$HOME/.todo.actions.d}/ 2>/dev/null)"

    OPTS="-@ -@@ -+ -++ -d -f -h -p -P -PP -a -n -t -v -vv -V -x"

    if [ $COMP_CWORD -eq 1 ]; then
	completions="$COMMANDS $OPTS"
    else
	case "${prev}" in
	    -*) completions="$COMMANDS $OPTS";;
	    *)  return 0;;
	esac
    fi

    COMPREPLY=( $( compgen -W "$completions" -- $cur ))
    return 0
}

complete -F _metasystem_todo_complete todo.sh
complete -F _metasystem_todo_complete todo


#------------------------------------------------------------------------------
# Command-line completion
#------------------------------------------------------------------------------

[[ -e /etc/bash_completion ]] && source /etc/bash_completion


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

export -f _metasystem_print_banner


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
# ssh-agent
#------------------------------------------------------------------------------

SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}-${METASYSTEM_OS}-${METASYSTEM_PLATFORM}"

function ssh_agent_pid()
{
	if [[ -n ${SSH_AGENT_PID} ]]; then
		ps -ef | grep $SSH_AGENT_PID | grep ssh-agent$ > /dev/null
		[[ $? == 0 ]] && echo $SSH_AGENT_PID
	fi
}

function ssh_agent_start()
{
	echo -n "Starting ssh-agent ... "
	local pid=$(ssh_agent_pid)
	if [[ -n $pid ]]; then
		echo "already active PID $pid"
	else
		rm -f ${SSH_AGENT_ENV}
		ssh-agent | sed 's/^echo/#echo/' > ${SSH_AGENT_ENV}
		chmod 600 "${SSH_AGENT_ENV}"
		export SSH_AGENT_PID=
		. ${SSH_AGENT_ENV} > /dev/null
		if [[ -n $SSH_AGENT_PID ]]; then
			echo "PID $SSH_AGENT_PID"
			ssh-add
		else
			echo "failed"
		fi
	fi
}

function ssh_agent_stop()
{
	echo "Stopping ssh-agent ..."
	local pid=$(ssh_agent_pid)
	[[ -n $pid ]] && kill -9 $pid
	rm -f ${SSH_AGENT_ENV}
}

if [[ -z $METASYSTEM_DISABLE_SSH_AGENT ]]; then
	_metasystem_print_banner "ssh-agent"
	[[ -f ${SSH_AGENT_ENV} ]] && source ${SSH_AGENT_ENV} > /dev/null
	ssh_agent_start
fi


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


#==============================================================================
# Modules
#==============================================================================

source $METASYSTEM_CORE_SHELL/modules.sh


#==============================================================================
# Opt
#==============================================================================

_metasystem_print_banner "Optional packages"
source $METASYSTEM_CORE_SHELL/opt/config


#==============================================================================
# Local config
#==============================================================================

_metasystem_print_banner "Local config"

if [[ -n $METASYSTEM_LOCAL_SHELL ]]; then
	echo -e "Loading $METASYSTEM_LOCAL_SHELL/shrc.sh ..."
	source $METASYSTEM_LOCAL_SHELL/shrc.sh
	PATH=$(path_prepend $METASYSTEM_LOCAL_BIN $PATH)
else
	echo -e "${NAKED_LIGHT_RED}$metasystem_local_root not found${NAKED_NO_COLOR}"
	echo "Using template config files from $METASYSTEM_CORE_CONFIG"
	echo "To create a metasystem-local repo, run 'metasystem_create_local'"
fi

function metasystem_create_local()
{
	if [[ -e $metasystem_local_root ]]; then
		echo "Error: $metasystem_local_root already exists"
		return 1
	else
		cp -rv $METASYSTEM_CORE_TEMPLATES/local $metasystem_local_root
		cp -v $METASYSTEM_CORE_ROOT/.gitignore $metasystem_local_root
		cd $metasystem_local_root
		git init
		git add -A
		git commit -m "Initial version (created from template)"
	fi
}


#==============================================================================
# Core setup 2/2
#==============================================================================

#------------------------------------------------------------------------------
# Profile
#------------------------------------------------------------------------------

function profile_update()
{
	local args="--reset --auto all"
	local global=
	for arg in $*
	do
		args="$args --user $arg"
	done

	echo "Setting profile for this shell session"

	local cmd="metasystem-profile.py --verbose set $args"
	echo $cmd

	local path=$PATH
	[[ -n $METASYSTEM_OPT_SYMBIAN ]] && path=$(path_remove_epoc $path)

	PATH=$path $cmd

	[[ $global != 1 ]] && source ~/.metasystem-profile

	metasystem-id.py generate --script
}

alias profile-get='source ~/.metasystem-profile'
alias profile-print='metasystem-profile.py print'
alias profile='profile-print'
alias profile-update=profile_update

if [[ -z $METASYSTEM_DISABLE_PROFILE ]]; then
	_metasystem_print_banner "Profile"
	if [[ -e ~/.metasystem-profile ]]; then
		echo "Sourcing existing .metasystem-profile"
		profile-get
	else
		profile-update
	fi
fi


#------------------------------------------------------------------------------
# Identities
#------------------------------------------------------------------------------

function _metasystem_update_prompt_ids()
{
	_prompt_ids=
	for id_type in $METASYSTEM_ID_TYPES
	do
		local id_type_uc=$(uppercase $id_type)
		eval local id=\$METASYSTEM_ID_${id_type_uc}
		_prompt_ids="${_prompt_ids} ${LIGHT_CYAN}$id_type:$id${NAKED_NO_COLOUR}"
	done
}

function _metasystem_set_id()
{
	local label=$1
	local id=$2
	metasystem-id.py --quiet set $label $id
	source ~/.metasystem-id
	_metasystem_update_prompt_ids
}

function _metasystem_show_identity()
{
	echo "Available ID types: $METASYSTEM_ID_TYPES"
	echo "Available IDs:      $METASYSTEM_IDS"
	echo
	echo "Currently active identities:"
	for id_type in $METASYSTEM_ID_TYPES
	do
		local id_type_uc=$(uppercase $id_type)
		eval local id=\$METASYSTEM_ID_${id_type_uc}
		echo -e "    $id_type = $id"
	done
}

function _metasystem_reset_ids()
{
	metasystem-id.py --quiet generate --reset --script
	source ~/.metasystem-id
}

function _metasystem_print_ids()
{
	for id_type in $METASYSTEM_ID_TYPES
	do
		local id_type_uc=$(uppercase $id_type)
		eval local id=\$METASYSTEM_ID_${id_type_uc}
		echo "$id_type: $id"
	done
}

alias ids-get='source ~/.metasystem-id'
alias ids-print='_metasystem_print_ids'
alias ids=ids-print
alias i=ids
alias id-set='_metasystem_set_id'
alias ids-reset='_metasystem_reset_ids'


#------------------------------------------------------------------------------
# Tools
#------------------------------------------------------------------------------

function _metasystem_print_tools()
{
	for tool_type in $METASYSTEM_TOOL_TYPES
	do
		local tool_type_uc=$(uppercase $tool_type)
		eval local tool_name=\$METASYSTEM_TOOL_${tool_type_uc}
		echo "$tool_type: $tool_name"
	done
}

function _metasystem_set_tool()
{
	local tool_type=$1
	local name=$2
	metasystem-tools.py set $tool_type $name
	source ~/.metasystem-tools
	_metasystem_update_prompt_tools
}

function _metasystem_reset_tools()
{
	metasystem-tools.py generate
	source ~/.metasystem-tools
}

function _metasystem_update_prompt_tools()
{
	_prompt_tools=
	_metasystem_prompt_tools_enabled=no
	for tool_type in $METASYSTEM_TOOL_TYPES
	do
		local tool_type_uc=$(uppercase $tool_type)
		eval local tool_name=\$METASYSTEM_TOOL_${tool_type_uc}
		[[ -n $tool_name ]] && _metasystem_prompt_tools_enabled=yes
		_prompt_tools="${_prompt_tools} ${LIGHT_RED}$tool_type:$tool_name${NO_COLOUR}"
	done
}

alias tools-get='source ~/.metasystem-tools'
alias tools-print='_metasystem_print_tools'
alias tools=tools-print
alias t=tools
alias tool-set='_metasystem_set_tool'
alias tools-reset='_metasystem_reset_tools'

export -f _metasystem_update_prompt_tools


#------------------------------------------------------------------------------
# Projects
#------------------------------------------------------------------------------

export METASYSTEM_PROJECTS=

# Global variables
_metasystem_projectdirs_updated=

function metasystem_project_env_prefix()
{
	local project=$1
	echo METASYSTEM_PROJECT_$(uppercase ${project//-/_})
}

function _metasystem_do_set_projectdirs()
{
	local project=$1
	local project_env_prefix=$(metasystem_project_env_prefix $project)
	local build_dir=$2
	local source_dir=$3
	local old_build_dir
	eval old_build_dir=\$${project_env_prefix}_BUILD_DIR
	_metasystem_projectdirs_updated=

	if [[ -n $build_dir ]]; then
		eval _metasystem_export ${project_env_prefix}_BUILD_DIR=$build_dir
		eval _metasystem_export ${project_env_prefix}_SOURCE_DIR=$source_dir
		eval _${project_env_prefix}_DIRS_SET=${PWD/\//\\\/}
		_metasystem_projectdirs_updated=1
	else
		# If _${project_env_prefix}_DIRS_SET is non-empty and is not a parent of the current
		# directory, clear the ${project_env_prefix}_*_DIR variables
		eval local d=\$_${project_env_prefix}_DIRS_SET
		if [[ -n $d ]]; then
			if [[ $PWD == $d* ]]; then
				eval _${project_env_prefix}_DIRS_SET=
				eval _metasystem_export ${project_env_prefix}_BUILD_DIR=
				eval _metasystem_export ${project_env_prefix}_SOURCE_DIR=
				_metasystem_projectdirs_updated=1
			fi
		fi
	fi
}

function _metasystem_set_projectdirs()
{
	local project=$1
	local build_dir=$2
	local source_dir=$3

	if [[ -n $METASYSTEM_OPT_QT ]]; then
		if [[ $project == qt ]]; then
			_metasystem_set_qtdirs "$build_dir" "$source_dir"
		else
			if [[ $project == qtmobility ]]; then
				_metasystem_export QTMOBILITY_BUILD_DIR=$build_dir
				_metasystem_export QTMOBILITY_SOURCE_DIR=$source_dir
			fi
			_metasystem_do_set_projectdirs $project "$build_dir" "$source_dir"
		fi
	fi
}

function _metasystem_update_projects()
{
	local projects=${1//,/ }
	for x in $METASYSTEM_PROJECTS; do
		still_exists=
		for y in $projects; do
			[[ $x == $y ]] && still_exists=1
		done
		[[ -z $still_exists ]] && _metasystem_set_projectdirs $x '' ''
	done
	_metasystem_export METASYSTEM_PROJECTS=$projects
}

function _metasystem_projects_print()
{
	[[ -n $EPOCROOT ]] && echo "epoc: $EPOCROOT"
	for project in $METASYSTEM_PROJECTS
	do
		local prompt_info=
		local project_env_prefix=$(metasystem_project_env_prefix $project)
		eval local source_dir=\$${project_env_prefix}_SOURCE_DIR
		eval local build_dir=\$${project_env_prefix}_BUILD_DIR
		if [[ $source_dir == $build_dir ]]; then
			if [[ -n $build_dir ]]; then
				echo -e "${NAKED_LIGHT_RED}${project}: ${build_dir}${NAKED_NO_COLOR}"
			else
				if [[ -n $source_dir && -d $source_dir ]]; then
					echo -e "${NAKED_LIGHT_RED}${project}-source: ${source_dir}${NAKED_NO_COLOR}"
				fi
			fi
		else
			if [[ -n $build_dir ]]; then
				echo -e "${NAKED_LIGHT_RED}${project}-build: ${build_dir}${NAKED_NO_COLOR}"
				if [[ -n ${source_dir} && -d ${source_dir} ]]; then
					echo -e "${NAKED_LIGHT_RED}${project}-source: ${source_dir}${NAKED_NO_COLOR}"
				fi
			else
				if [[ -n $source_dir && -d $source_dir ]]; then
					echo -e
					"${NAKED_LIGHT_RED}${project}-source:${source_dir}${NAKED_NO_COLOUR}"
				fi
			fi
		fi
	done
}

function _metasystem_update_prompt_projects()
{
	# Projects
	_prompt_projects=
	for project in $METASYSTEM_PROJECTS
	do
		local prompt_info=
		local project_env_prefix=$(metasystem_project_env_prefix $project)
		eval local source_dir=\$${project_env_prefix}_SOURCE_DIR
		eval local build_dir=\$${project_env_prefix}_BUILD_DIR
		if [[ $source_dir == $build_dir ]]; then
			if [[ -n $build_dir ]]; then
				prompt_info="${PINK}${project}:${build_dir}${NO_COLOUR}"
			else
				if [[ -n $source_dir && -d $source_dir ]]; then
					prompt_info="${PINK}${project}-source:${source_dir}${NO_COLOUR}"
				fi
			fi
		else
			if [[ -n $build_dir ]]; then
				prompt_info="${PINK}${project}-build:${build_dir}${NO_COLOUR}"
				if [[ -n ${source_dir} && -d ${source_dir} ]]; then
					prompt_info="$prompt_info\n${PINK}${project}-source:${source_dir}${NO_COLOUR}"
				fi
			else
				if [[ -n $source_dir && -d $source_dir ]]; then
					prompt_info="${PINK}${project}-source:${source_dir}${NO_COLOUR}"
				fi
			fi
		fi
	[[ -n $prompt_info ]] && _prompt_projects="$_prompt_projects$prompt_info\n"
	done
}

function metasystem_project_cd_build()
{
	local arg=$1
	local project=`echo $arg | sed -e 's/\/.*//'`
	local path=`echo $arg | sed -e 's/[a-zA-Z]*\///'`
	local project_env_prefix=$(metasystem_project_env_prefix $project)
	eval local build_dir=\$${project_env_prefix}_BUILD_DIR
	[[ $path == $project ]] && path=
	if [[ -n $build_dir ]]; then
		metasystem_cd $build_dir/$path
	else
		echo "pcd: '$arg' not recognized"
		return 1
	fi
}

function metasystem_project_cd_source()
{
	local arg=$1
	local project=`echo $arg | sed -e 's/\/.*//'`
	local path=`echo $arg | sed -e 's/[a-zA-Z]*\///'`
	local project_env_prefix=$(metasystem_project_env_prefix $project)
	eval local source_dir=\$${project_env_prefix}_SOURCE_DIR
	[[ $path == $project ]] && path=
	if [[ -n $source_dir ]]; then
		metasystem_cd $source_dir/$path
	else
		echo "pcd: '$arg' not recognized"
		return 1
	fi
}

export -f metasystem_project_env_prefix
export -f metasystem_project_cd_build
export -f metasystem_project_cd_source

alias pcdb='metasystem_project_cd_build'
alias pcds='metasystem_project_cd_source'
alias pcd='pcdb'

function _metasystem_complete_pcd()
{
	local suffix=$1
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local path=`echo $cur | sed -e 's/[a-zA-Z]*\///'`
	if [[ $path == $cur ]]; then
		COMPREPLY=( $(compgen -W "${METASYSTEM_PROJECTS}" -- ${cur}) )
	else
		local project=`echo $cur | sed -e 's/\/.*//'`
		local project_uc=$(uppercase $project)
		eval local dir=\$${project_uc}${suffix}
		local path_part=`echo $path | sed -e 's/\/[a-zA-Z]*$/\//'`
		local path_rest=
		if [[ -d $dir/$path_part ]]; then
			path_rest=`echo $path | tail -c+\`echo $path_part | wc -c\``
		else
			path_rest=$path_part
			path_part=
		fi
		reply=( $(compgen -W "`'ls' $dir/$path_part`" -- "${path_rest}") )
		path_part="/$path_part"
		COMPREPLY=( "${reply[@]/#/$project$path_part}" )
	fi
}

function _metasystem_complete_pcdb()
{
	_metasystem_complete_pcd _BUILD_DIR
}

function _metasystem_complete_pcds()
{
	_metasystem_complete_pcd _SOURCE_DIR
}

complete -F _metasystem_complete_pcdb pcd
complete -F _metasystem_complete_pcdb pcdb
complete -F _metasystem_complete_pcds pcds

alias projects-print=_metasystem_projects_print
alias projects=projects-print
alias p=projects


#------------------------------------------------------------------------------
# SCM
#------------------------------------------------------------------------------

alias git='scm-wrapper.sh git'
alias hg='scm-wrapper.sh hg'

function metasystem_install_git_hooks()
{
	local hook_dir=.git/hooks
	if [[ -d $hook_dir ]]; then
		builtin cd $hook_dir
		for sample in $('ls' *.sample); do
			dst=${sample//.sample/}
			src=$METASYSTEM_CORE_LIB/git-hooks/$dst
			[[ -e $src ]] && rm -f $dst && ln -s $src $dst
		done
		builtin cd ../..
	else
		echo "Error: .git/hooks not found" >&2
		return 1
	fi
}

export -f metasystem_install_git_hooks

export HGEXT_DIR=$(metasystem_nativepath ~/work/sync/hg/hgext)


#------------------------------------------------------------------------------
# IDEs
#------------------------------------------------------------------------------

alias eclipse="metasystem_run_bg eclipsec"


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

_METASYSTEM_PROMPT_ELEMENTS='ids epocroot git projects tools'

_metasystem_prompt_android_enabled=$METASYSTEM_OPT_ANDROID
_metasystem_prompt_ids_enabled=yes
_metasystem_prompt_epocroot_enabled=$METASYSTEM_OPT_SYMBIAN
_metasystem_prompt_git_enabled=yes
_metasystem_prompt_projects_enabled=no
_metasystem_prompt_tools_enabled=yes

function _metasystem_prompt_print()
{
	echo
	for element in $_METASYSTEM_PROMPT_ELEMENTS
	do
		eval local value=\$_metasystem_prompt_${element}_enabled
		echo "$element: $value"
	done
}

function _metasystem_prompt_set()
{
	local element=$1
	local value=$2
	[[ -z $value ]] && value=no
	[[ -n $element ]] && eval _metasystem_prompt_${element}_enabled=$value
}

function _metasystem_prompt_enable()
{
	_metasystem_prompt_set $1 yes
}

function _metasystem_prompt_disable()
{
	_metasystem_prompt_set $1 no
}

# http://railstips.org/blog/archives/2009/02/02/bedazzle-your-bash-prompt-with-git-info/
# Alternatively, from http://asemanfar.com/Current-Git-Branch-in-Bash-Prompt
# git name-rev HEAD 2> /dev/null | awk "{ print \\$2 }"
function _metasystem_git_branch_prompt()
{
    local ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    [[ -n $ref ]] && echo "${PINK}git:${ref#refs/heads/}${NO_COLOUR}"
}

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
function _metasystem_update_prompt()
{
	_metasystem_short_path=$(metasystem_short_path $PWD)
	_metasystem_short_dirinfo_root=
	[[ $METASYSTEM_DIRINFO_ROOT != $HOME ]] &&\
		_metasystem_short_dirinfo_root=$(metasystem_short_path $METASYSTEM_DIRINFO_ROOT)
	_metasystem_update_prompt_projects
	_metasystem_update_prompt_ids
	_metasystem_update_prompt_tools
}

export -f _metasystem_update_prompt

# This is run before every prompt is displayed
function _metasystem_prompt_command()
{
	# Do this first to ensure we get the correct value of $?
	local rc=$?
	local prompt_rc=
	[[ $rc != 0 ]] && local prompt_rc="${LIGHT_CYAN}$rc ${NO_COLOUR}"

	local prompt=

	[[ -n $METASYSTEM_DIRINFO_LABEL ]] &&
		prompt="${prompt}${LIGHT_PURPLE}${METASYSTEM_DIRINFO_LABEL}${NO_COLOUR} "

	[[ -n $_metasystem_short_dirinfo_root ]] &&\
		prompt="${prompt}${LIGHT_CYAN}${_metasystem_short_dirinfo_root}${NO_COLOUR} "

	[[ -n $prompt ]] && prompt="${prompt}\n"

	[[ $_metasystem_prompt_projects_enabled == yes ]] &&\
		prompt="${_prompt_projects}${prompt}"

	[[ $_metasystem_prompt_epocroot_enabled == yes && -n $EPOCROOT ]] &&\
		prompt="${LIGHT_RED}epoc: $EPOCROOT${NAKED_NO_COLOUR}\n${prompt}"

	# user@host pwd(short)
	local hostname=$HOSTNAME
	[[ -n $METASYSTEM_PROFILE_HOST ]] && hostname=$METASYSTEM_PROFILE_HOST
	prompt="${prompt}\[\e]0;\w\a\]${LIGHT_BLUE}\u@${hostname} ${LIGHT_YELLOW}${_metasystem_short_path}${NO_COLOUR}"
	[[ $_metasystem_prompt_git_enabled == yes ]] &&\
		prompt="${prompt} $(_metasystem_git_branch_prompt)"

	# Android
	local android=
	if [[ -n $_metasystem_prompt_android_enabled ]]; then
		[[ -n $TARGET_PRODUCT && -n $TARGET_BUILD_VARIANT ]] &&\
			android="\n${LIGHT_GREEN}android: ${TARGET_PRODUCT}-${TARGET_BUILD_VARIANT}${NO_COLOR}"
	fi
	prompt="${prompt}${android}"

	# time
	prompt="${prompt}\n${LIGHT_YELLOW}\A${NO_COLOUR}"

	[[ $_metasystem_prompt_tools_enabled == yes ]] &&\
		prompt="${prompt}${_prompt_tools}"

	[[ $_metasystem_prompt_ids_enabled == yes ]] &&\
		prompt="${prompt}${_prompt_ids}"

	export PS1="\n${prompt}\n${prompt_rc}\$ "
}

export PROMPT_COMMAND=_metasystem_prompt_command

alias prompt-print='_metasystem_prompt_print'
alias prompt=prompt-print
alias prompt-enable='_metasystem_prompt_enable'
alias prompt-disable='_metasystem_prompt_disable'


#------------------------------------------------------------------------------
# 'cd' trigger
#------------------------------------------------------------------------------

function metasystem_cd()
{
	local projects=$METASYSTEM_PROJECTS
	_metasystem_cd $*
	[[ $projects != $METASYSTEM_PROJECTS ]] && _metasystem_projects_print
	_metasystem_update_prompt
}

function metasystem_rcd()
{
	[[ -n $METASYSTEM_DIRINFO_ROOT ]] && metasystem_cd $METASYSTEM_DIRINFO_ROOT
}

function metasystem_stash_cd()
{
	_metasystem_stash_cd=$PWD
	builtin cd "$@"
}

function metasystem_unstash_cd()
{
	[[ -n $_metasystem_stash_cd ]] && builtin cd $_metasystem_stash_cd
	_metasystem_stash_cd=
}

export -f metasystem_cd
export -f metasystem_rcd
export -f metasystem_stash_cd
export -f metasystem_unstash_cd

alias cd=metasystem_cd
alias rcd=metasystem_rcd


#------------------------------------------------------------------------------
# Config files
#------------------------------------------------------------------------------

function do_rc_update()
{
	local rc=$1
	echo "Updating ~/.$rc"
	if [[ -e $METASYSTEM_LOCAL_TEMPLATES/home/$rc ]]; then
		subst-vars.sh --force $METASYSTEM_LOCAL_TEMPLATES/home/$rc ~/.$rc
	elif [[ -e $METASYSTEM_CORE_TEMPLATES/home/$rc ]]; then
		subst-vars.sh --force $METASYSTEM_CORE_TEMPLATES/home/$rc ~/.$rc
	fi
}

function rc_update()
{
	if [[ -z $1 ]]; then
		local rcs='astylerc inputrc vimrc ssh/config'
		for rc in $rcs; do
			do_rc_update $rc
		done
		echo "Updating ~/.gitconfig ..."
		echo "Updating ~/.hgrc ..."
		ids-reset
	else
		do_rc_update $1
	fi
}

alias rc-update=rc_update


#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

function _metasystem_help()
{
	cat << EOF

-------------------------------------------------------------------------------
Metasystem help
-------------------------------------------------------------------------------

Dirinfo
    dirinfo-init             Install dirinfo scripts in current directory

Profile
    profile-get              Source ~/.metasystem-profile
    profile                  Print current profile
    profile-update           Regenerate profile
                                 location=[name] Location
                                 rvct=[name]     RVCT license server

IDs
    ids-get                  Source ~/.metasystem-ids
    ids                      Print current IDs
    id-set [type] [name]     Set specified ID
    ids-reset                Reset IDs to default

Tools
    tools-get                Source ~/.metasystem-tools
    tools                    Print current tools
    tool-set [type] [name]   Set specified tool
    tools-reset              Reset tools to default

Projects
    projects                 Print current project directories

Directories
    pcdb [project]           Change to build directory for project
    pcds [project]           Change to source directory for project
    ecd                      Change directory to EPOCROOT
    rcd                      Change directory to METASYSTEM_DIRINFO_ROOT
    nativepath [path]        Translate path to native format
    unixpath [path]          Translate path to UNIX format

Miscellaneous
    rc-update                Regenerate dot files in home directory

-------------------------------------------------------------------------------

EOF
}

alias help='_metasystem_help'
alias h=help

echo -e "\n$_METASYSTEM_RULE"
echo -e "Type 'help' for a list of metasystem functions and aliases"
echo -e "$_METASYSTEM_RULE"


#==============================================================================
# Finalizing
#==============================================================================

# Ensure environment and prompt are correctly initialized
echo

metasystem_cd -metasystem-init
_metasystem_update_prompt_ids

[[ -n $have_python ]] && tools-reset
_metasystem_update_prompt_tools

[[ -n $have_python ]] && ids-reset

# Export final PATH
export PATH

# Don't know where these get set...
unset f
