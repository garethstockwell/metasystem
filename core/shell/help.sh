# help.sh

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

METASYSTEM_HELP_HOOKS=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_register_help_hook()
{
	local key=$1
	local var=METASYSTEM_HELP_$(echo $key)
	local value=$2
	echo "REG [$key] [$value]"
	eval "$(echo $var)=$value"
	[[ -z $(list_contains $key $METASYSTEM_HELP_HOOKS) ]] &&\
		METASYSTEM_HELP_HOOKS="$(list_append $key $METASYSTEM_HELP_HOOKS)"
}

function _metasystem_help_hook()
{
	local key=$1
	local var=METASYSTEM_HELP_$(echo $key)
	eval "echo \$$(eval echo $var)"
}

function _metasystem_help_default()
{
	cat << EOF
-------------------------------------------------------------------------------
Metasystem help
-------------------------------------------------------------------------------

Miscellaneous
    rc-update                Regenerate dot files in home directory

-------------------------------------------------------------------------------

EOF
}

function _metasystem_help_list()
{
	echo "Available help topics:"
	for hook in $METASYSTEM_HELP_HOOKS; do
		echo $hook
	done
}

function metasystem_help()
{
	local key=$1
	local hook=$(_metasystem_help_hook $key)

	if [[ -n $hook ]]; then
		_metasystem_print_banner "Metasystem help for $key"
		eval "$(echo $hook)"
		echo -e "$_METASYSTEM_RULE\n"
	else
		_metasystem_help_default
		_metasystem_help_list
	fi
}

alias help='metasystem_help'
alias h=help

