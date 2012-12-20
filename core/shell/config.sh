# config.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_set_config()
{
	local key=$1
	local var=METASYSTEM_CONFIG_$(echo $key)
	local value=$2
	eval "$(echo $var)=$value"
}

function metasystem_get_config()
{
	local key=$1
	local var=METASYSTEM_CONFIG_$(echo $key)
	eval "echo \$$(eval echo $var)"
}

function metasystem_set_config_default()
{
	local key=$1
	local default=$2
	if [[ -z $value ]]; then
		metasystem_set_config $key $default
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

metasystem_set_config_default PROMPT_IDS_ENABLED no
metasystem_set_config_default PROMPT_TOOLS_ENABLED yes

