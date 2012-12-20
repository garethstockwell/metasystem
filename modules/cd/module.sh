# modules/cd/module.sh

#------------------------------------------------------------------------------
# Functions
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

function metasystem_rcd()
{
	[[ -n $METASYSTEM_DIRINFO_ROOT ]] && metasystem_cd $METASYSTEM_DIRINFO_ROOT
}

function metasystem_parse_dirinfo()
{
	empty_function
}

function _metasystem_cd()
{
	[[ $1 != -metasystem-init ]] && builtin cd $*
}

function _metasystem_export()
{
	export "$@"
}

function _metasystem_unset()
{
	unset "$@"
}

function autostash()
{
	export "$@"
}

alias dirinfo-init='_metasystem_dirinfo_init'
alias rcd=metasystem_rcd


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_CD_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_CD_BIN=$METASYSTEM_CD_ROOT/bin


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_cd_hook_cd_post()
{
	_metasystem_short_dirinfo_root=
	[[ $METASYSTEM_DIRINFO_ROOT != $HOME ]] &&\
		_metasystem_short_dirinfo_root=$(path_shorten $METASYSTEM_DIRINFO_ROOT)
}

function _metasystem_cd_hook_prompt()
{
	local ret=
	[[ -n $METASYSTEM_DIRINFO_LABEL ]] &&
		ret="${NAKED_LIGHT_PURPLE}${METASYSTEM_DIRINFO_LABEL}${NAKED_NO_COLOUR} "
	[[ -n $_metasystem_short_dirinfo_root ]] &&\
		ret="${ret}${NAKED_LIGHT_PURPLE}(${_metasystem_short_dirinfo_root})${NAKED_NO_COLOUR}"
	echo $ret
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_CD_BIN $PATH)

metasystem_set_config_default CD smartcd

source $METASYSTEM_CD_ROOT/cd-${METASYSTEM_CONFIG_CD}.sh

