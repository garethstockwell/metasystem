# lib/bash/func.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function function_exists()
{
	local name=$1
	[[ -z $(declare -f $name) ]] && return 1
	return 0
}

# Syntax: rename_function <old_name> <new_name>
# http://stackoverflow.com/questions/1203583/how-do-i-rename-a-bash-function
function rename_function()
{
	local old_name=$1
	local new_name=$2
	eval "$(echo "${new_name}()"; declare -f ${old_name} | tail -n +2)"
	unset -f ${old_name}
}

# Syntax: prepend_to_function <name> [statements...]
function prepend_to_function()
{
	local name=$1
	shift
	local body="$@"
	eval "$(echo "${name}(){"; echo ${body}; declare -f ${name} | tail -n +3)"
}

# Syntax: append_to_function <name> [statements...]
function append_to_function()
{
	local name=$1
	shift
	local body="$@"
	eval "$(declare -f ${name} | head -n -1; echo ${body}; echo '}')"
}

function source_function()
{
	local name=$1
	local file=$2
	eval "$(echo "${name}() {"; cat ${file}; echo '}' )"
}

