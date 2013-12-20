# shrc.sh

#------------------------------------------------------------------------------
# Banner
#------------------------------------------------------------------------------

function _metasystem_print_rule()
{
	local cols=80
	if [[ $COLUMNS -lt $cols ]]; then
		cols=$COLUMNS
	fi

	printf "%${cols}s\n" | tr ' ' '-'
}

function _metasystem_print_banner()
{
	echo
	_metasystem_print_rule
	echo $1
	_metasystem_print_rule
}


#------------------------------------------------------------------------------
# Startup
#------------------------------------------------------------------------------

# Print something as early as possible, to show that the shell is starting
_metasystem_print_rule


#------------------------------------------------------------------------------
# Home
#------------------------------------------------------------------------------

_metasystem_start_dir=$PWD
builtin cd $HOME


#------------------------------------------------------------------------------
# Local profile
#------------------------------------------------------------------------------

if [[ -n $METASYSTEM_LOCAL_SHELL ]]; then
	if [[ -e $METASYSTEM_LOCAL_SHELL/profile.sh ]]; then
		source $METASYSTEM_LOCAL_SHELL/profile.sh
	fi
fi


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/utils.sh

source $METASYSTEM_CORE_LIB_BASH/color.sh
source $METASYSTEM_CORE_LIB_BASH/path.sh
source $METASYSTEM_CORE_LIB_BASH/string.sh

source $METASYSTEM_CORE_SHELL/autoload.sh
source $METASYSTEM_CORE_SHELL/config.sh
source $METASYSTEM_CORE_SHELL/help.sh


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

PATH=$(path_append_if_exists /usr/local/sbin $PATH)
PATH=$(path_append_if_exists /usr/sbin $PATH)
PATH=$(path_append_if_exists /sbin $PATH)


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias com='history | grep $1'
alias findproc='ps -ax -o %p%u%c%t | grep -v grep | grep $1'
alias du='du -h'
alias df='df -kh'

alias less='less -x4 -R'	# R is for cgrep

alias ls='ls -hF'
if [[ $METASYSTEM_OS == mac ]]; then
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

command_exists vim && alias vi='vim'

alias sync='metasystem-sync.py'

alias nativepath=metasystem_nativepath
alias npath=metasystem_nativepath
alias unixpath=metasystem_unixpath
alias upath=metasystem_unixpath

alias beep="echo $'\a'"

# Colorising grep
# Reads GREP_COLOR environment variable
# Note: requires 'less -R' to correctly interpret escapes
alias cgrep='grep --color=always'

alias path='path_split \\\\n $PATH'

# Avoid using the DOS ftp client
[[ $METASYSTEM_PLATFORM == mingw ]] && alias ftp='/bin/ftp.exe'

[[ $METASYSTEM_OS == linux ]] &&\
	alias rdp='metasystem_run_bg xfreerdp -d dir -u $USER -g 1920x1080 -a 32 -x l -o'


#------------------------------------------------------------------------------
# System information
#------------------------------------------------------------------------------

echo "Hostname:   $METASYSTEM_HOSTNAME"
echo "Domain:     $($METASYSTEM_CORE_BIN/network-info.py domain)"
echo "IP address: $($METASYSTEM_CORE_BIN/network-info.py ip)"
echo "OS:         $METASYSTEM_OS"
echo "OS vendor:  $METASYSTEM_OS_VENDOR"
echo "OS version: $METASYSTEM_OS_VERSION"
echo "Platform:   $METASYSTEM_PLATFORM"


#------------------------------------------------------------------------------
# Prompt
#------------------------------------------------------------------------------

# This is triggered when the directory is changed
function _metasystem_prompt_update_cd()
{
	_path_shorten=$(path_shorten $PWD)
	local chroot=
	[[ -n $(declare -f chroot_desc) ]] && chroot=$(chroot_desc)
	local title=$_path_shorten
	[[ -n $chroot ]] && title="[$chroot] $title"
	[[ $TERM == xterm ]] && xterm_set_title $title
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
	func_append_to _metasystem_prompt_hooks $body
}

function _metasystem_prompt()
{
	# Do this first to ensure we get the correct value of $?
	local rc=$?
	local prompt_rc=
	[[ $rc != 0 ]] && local prompt_rc="${LIGHT_PURPLE}$rc ${NO_COLOUR}"

	local prompt=

	[[ -n $prompt ]] && prompt="${prompt}\n"

	if [[ -n $ZSH_VERSION ]]; then
		local user='%n'
		local time='%D{%H:%M}'
	else
		local user='\u'
		local time='\A'
	fi

	local chroot=
	if metasystem_module_loaded chroot; then
		if _metasystem_chroot; then
			chroot="${LIGHT_BLUE}[$(chroot_name)]${NO_COLOUR}"
		fi
	fi

	local hostname=$HOSTNAME
	[[ -z $hostname ]] && hostname=$HOST
	[[ -n $METASYSTEM_PROFILE_HOST ]] && hostname=$METASYSTEM_PROFILE_HOST
	prompt="${prompt}${LIGHT_BLUE}${user}@${hostname}${chroot} ${LIGHT_YELLOW}${_path_shorten}${NO_COLOUR}"

	prompt="${prompt}${_prompt_tools}${_prompt_ids}"

	local prompt_hooks="$(_metasystem_prompt_hooks)"
	[[ -n $prompt_hooks ]] && prompt="${prompt}\n${prompt_hooks}"

	local prompt_time="${LIGHT_YELLOW}${time}${NO_COLOUR}"
	echo "\n${prompt}\n${prompt_rc}${prompt_time} \$ "
}


#------------------------------------------------------------------------------
# cd
#------------------------------------------------------------------------------

function _metasystem_export()
{
	export "$@"
}

function _metasystem_cd_pre_hooks()
{
	echo > /dev/null
}

function _metasystem_cd_post_hooks()
{
	echo > /dev/null
}

function _metasystem_cd()
{
	if [[ "$1" != "-metasystem-init" ]]; then
        builtin cd $*
    fi
}

# Register a function which will be called before cd
function metasystem_register_cd_pre_hook()
{
	local body=$1
	func_append_to _metasystem_cd_pre_hooks $body
}

# Register a function which will be called after cd
function metasystem_register_cd_post_hook()
{
	local body=$1
	func_append_to _metasystem_cd_post_hooks $body
}

function metasystem_cd()
{
	_metasystem_cd_pre_hooks
	_metasystem_cd $*
	_metasystem_cd_post_hooks
	_metasystem_prompt_update_cd
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

alias cd=metasystem_cd


#------------------------------------------------------------------------------
# Init
#------------------------------------------------------------------------------

function _metasystem_init_hooks()
{
	echo > /dev/null
}

# Register a function which will be called at the end of this script
function metasystem_register_init_hook()
{
	local body=$1
	func_append_to _metasystem_init_hooks $body
}


#------------------------------------------------------------------------------
# Identities
#------------------------------------------------------------------------------

function _metasystem_update_prompt_ids()
{
	if [[ $(metasystem_get_config PROMPT_IDS_ENABLED) == yes ]]; then
		_prompt_ids=
		for id_type in $METASYSTEM_ID_TYPES
		do
			local id_type_uc=$(uppercase $id_type)
			eval local id=\$METASYSTEM_ID_${id_type_uc}
			_prompt_ids="${_prompt_ids} ${LIGHT_CYAN}$id_type:$id${NO_COLOUR}"
		done
	fi
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
	_metasystem_update_prompt_ids
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

function _metasystem_hook_ids_init()
{
	[[ -n $(which python) ]] && _metasystem_reset_ids
}

alias ids-get='source ~/.metasystem-id'
alias ids-print='_metasystem_print_ids'
alias ids=ids-print
alias i=ids
alias id-set='_metasystem_set_id'
alias ids-reset='_metasystem_reset_ids'

metasystem_register_init_hook _metasystem_hook_ids_init


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
	_metasystem_update_prompt_tools
}

function _metasystem_update_prompt_tools()
{
	if [[ $(metasystem_get_config PROMPT_TOOLS_ENABLED) == yes ]]; then
		local ok=
		_prompt_tools=
		for tool_type in $METASYSTEM_TOOL_TYPES
		do
			local tool_type_uc=$(uppercase $tool_type)
			eval local tool_name=\$METASYSTEM_TOOL_${tool_type_uc}
			[[ -n $tool_name ]] && ok=yes
			_prompt_tools="${_prompt_tools} ${LIGHT_RED}$tool_type:$tool_name${NO_COLOUR}"
		done
		[[ -z $ok ]] && _prompt_tools=
	fi
}

function _metasystem_hook_tools_init()
{
	[[ -n $(which python) ]] && _metasystem_reset_tools
}

alias tools-get='source ~/.metasystem-tools'
alias tools-print='_metasystem_print_tools'
alias tools=tools-print
alias t=tools
alias tool-set='_metasystem_set_tool'
alias tools-reset='_metasystem_reset_tools'

metasystem_register_init_hook _metasystem_hook_tools_init


#------------------------------------------------------------------------------
# Projects
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/project.sh

export METASYSTEM_PROJECTS=

# Global variables
_metasystem_projectdirs_updated=
_metasystem_projects=

function _metasystem_set_projectdirs()
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
				eval _metasystem_export ${project_env_prefix}_CHROOT=
				_metasystem_projectdirs_updated=1
			fi
		fi
	fi
}

function _metasystem_set_project_chroot()
{
	local project=$1
	local project_env_prefix=$(metasystem_project_env_prefix $project)
	local chroot=$2
	eval _metasystem_export ${project_env_prefix}_CHROOT=$chroot
}

function _metasystem_projects_print()
{
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

function _metasystem_enter_chroot()
{
	echo "Error: _metasystem_enter_chroot is undefined" >&2
	return 1
}

function _metasystem_project_cd()
{
	local type=$1
	local arg=$2
	local project=`echo $arg | sed -e 's/\/.*//'`
	local lpath=`echo $arg | sed -e 's/[a-zA-Z]*\///'`
	local project_env_prefix=$(metasystem_project_env_prefix $project)
	eval local dir=\$${project_env_prefix}_$(uppercase $type)_DIR
	eval local chroot=\$${project_env_prefix}_CHROOT
	[[ $lpath == $project ]] && lpath=
	if [[ -n $dir ]]; then
		if [[ -n $chroot ]]; then
			_metasystem_enter_chroot $chroot $dir/$lpath
		else
			metasystem_cd $dir/$lpath
		fi
	else
		echo "pcd: '$arg' not recognized"
		return 1
	fi
}

function metasystem_project_cd_build()
{
	_metasystem_project_cd build $*
}

function metasystem_project_cd_source()
{
	_metasystem_project_cd source $*
}

function _metasystem_complete_pcd()
{
	local suffix=$1
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local lpath=`echo $cur | sed -e 's/[a-zA-Z]*\///'`
	if [[ $lpath == $cur ]]; then
		COMPREPLY=( $(compgen -W "${METASYSTEM_PROJECTS}" -- ${cur}) )
	else
		local project=`echo $cur | sed -e 's/\/.*//'`
		local project_uc=$(uppercase $project)
		eval local dir=\$${project_uc}${suffix}
		local path_part=`echo $lpath | sed -e 's/\/[a-zA-Z]*$/\//'`
		local path_rest=
		if [[ -d $dir/$path_part ]]; then
			path_rest=`echo $lpath | tail -c+\`echo $path_part | wc -c\``
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

function _metasystem_projects_cd_pre_hook()
{
	_metasystem_projects=$METASYSTEM_PROJECTS
}

function _metasystem_projects_cd_post_hook()
{
	[[ $_metasystem_projects != $METASYSTEM_PROJECTS ]] && _metasystem_projects_print
}

if [[ -n $BASH_VERSION ]]; then
	complete -F _metasystem_complete_pcdb pcd
	complete -F _metasystem_complete_pcdb pcdb
	complete -F _metasystem_complete_pcds pcds
fi

alias pcdb='metasystem_project_cd_build'
alias pcds='metasystem_project_cd_source'
alias pcd='pcdb'

alias projects-print=_metasystem_projects_print
alias projects=projects-print
alias p=projects

metasystem_register_cd_pre_hook _metasystem_projects_cd_pre_hook
metasystem_register_cd_post_hook _metasystem_projects_cd_post_hook


#------------------------------------------------------------------------------
# Config files
#------------------------------------------------------------------------------

function _metasystem_do_rc_update()
{
	local rc=$1
	echo "Updating ~/.$rc"
	if [[ -e $METASYSTEM_LOCAL_TEMPLATES/home/$rc ]]; then
		subst-vars.sh --force $METASYSTEM_LOCAL_TEMPLATES/home/$rc ~/.$rc
	elif [[ -e $METASYSTEM_CORE_TEMPLATES/home/$rc ]]; then
		subst-vars.sh --force $METASYSTEM_CORE_TEMPLATES/home/$rc ~/.$rc
	fi
}

function _metasystem_rc_update()
{
	if [[ -z $1 ]]; then
		local rcs=$(builtin cd $METASYSTEM_CORE_TEMPLATES/home &&\
			        find -type f | sed -e 's/\.\///')
		for rc in $rcs; do
			if [[ $rc != gitconfig && $rc != hgrc ]]; then
				_metasystem_do_rc_update $rc
			fi
		done
		echo "Updating ~/.gitconfig ..."
		echo "Updating ~/.hgrc ..."
		_metasystem_reset_ids
	else
		_metasystem_do_rc_update $1
	fi
}

alias rc-update=_metasystem_rc_update


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
		cp -v $METASYSTEM_ROOT/.gitignore $metasystem_local_root
		pushd $metasystem_local_root
		git init
		git add -A
		git commit -m "Initial version (created from template)"
		popd
	fi
}


#==============================================================================
# Modules
#==============================================================================

source $METASYSTEM_CORE_SHELL/modules.sh


#==============================================================================
# Finalizing
#==============================================================================

metasystem_cd -metasystem-init

_metasystem_init_hooks

# Export final PATH
path_remove_invalid
export PATH

# Don't know where these get set...
unset f

_metasystem_print_banner "Type 'help' for a list of metasystem functions and aliases"

metasystem_cd $_metasystem_start_dir
unset _metasystem_start_dir

#clear

