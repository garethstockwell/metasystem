# cd.sh

#------------------------------------------------------------------------------
# Stub functions
#------------------------------------------------------------------------------

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


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

if [[ -n $METASYSTEM_CONFIG_CD ]]; then
	source $METASYSTEM_CORE_SHELL/cd-${METASYSTEM_CONFIG_CD}.sh
fi

