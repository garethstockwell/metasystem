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
# Platform
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/platform.sh
query_platform


#------------------------------------------------------------------------------
# Local profile
#------------------------------------------------------------------------------

if [[ -n $METASYSTEM_LOCAL_SHELL ]]; then
	if [[ -e $METASYSTEM_LOCAL_SHELL/profile.sh ]]; then
		source $METASYSTEM_LOCAL_SHELL/profile.sh
	fi
fi


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
# Dotfiles
#------------------------------------------------------------------------------

_METASYSTEM_DOTFILES=

function _metasystem_dotfile_register()
{
	local key=$1
	local src=$2
	local dst=$3
	local start=$4
	local str=${key}:${src}:${dst}:${start}
	_METASYSTEM_DOTFILES=$(list_append ${str} ${_METASYSTEM_DOTFILES})
}

function _metasystem_dotfile_update()
{
	local search_key=$1

	for entry in $_METASYSTEM_DOTFILES; do
		local key=$(echo $entry | cut -d: -f1)

		local is_local=yes
		[[ $key == local.* ]] || is_local=

		key=${key/local\./}

		if [[ -z $search_key || $key == $search_key ]]; then

			local src=$(echo $entry | cut -d: -f2)
			local dst=$(echo $entry | cut -d: -f3)
			local start=$(echo $entry | cut -d: -f4)

			if [[ -z $dst ]]; then
				dst=$src
			fi

			local dst_path=$HOME/.${dst}

			local src_path=

			if [[ -n $METASYSTEM_LOCAL_DOTFILES ]]; then
				src_path=$METASYSTEM_LOCAL_DOTFILES/$key/$src
				if [[ ! -r $src_path ]]; then
					src_path=
				fi
			fi

			if [[ -z $src_path ]]; then
				if [[ -n $is_local ]]; then
					src_path=$METASYSTEM_LOCAL_ROOT/modules/$key/dotfiles/$src
				else
					src_path=$METASYSTEM_ROOT/modules/$key/dotfiles/$src
				fi
			fi

			echo "$key: $src -> $dst [$start]"

			if [[ ! -z $src_path && -e $src_path ]]; then
				mkdir -p $(dirname $dst_path)

				args=
				if [[ -n $start ]]; then
					args="--start $start"
				fi
				subst-vars.sh --force $src_path $dst_path $args
			fi
		fi
	done
}

alias dotfile-update=_metasystem_dotfile_update


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


#------------------------------------------------------------------------------
# Exit
#------------------------------------------------------------------------------

function exit()
{
	local suppress=

	if [[ -n $TMUX ]]; then
		ask "Really exit the shell?" || suppress=1
	fi

	[[ -n $suppress ]] || command exit
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
