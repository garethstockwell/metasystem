# metasystem/shell/modules.sh

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

METASYSTEM_MODULES_LOADED=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function _metasystem_module_register_hooks()
{
	local module=$1
	for hook in prompt cd_pre cd_post init; do
		local func=_metasystem_hook_${module//-/_}_${hook}
		local register=metasystem_register_${hook}_hook
		$(func_exists $func) && eval "$(echo $register) $(echo $func)"
	done

	local func=_metasystem_hook_${module//-/_}_help
	$(func_exists $func) && metasystem_register_help_hook $module $func
}

function _metasystem_module_dir()
{
	local type=$1
	local result=

	case $type in
		core)
			result=$METASYSTEM_ROOT/modules
			;;
		local)
			[[ -n $METASYSTEM_LOCAL_ROOT ]] || return
			result=$METASYSTEM_LOCAL_ROOT/modules
			;;
		*)
			echo "Error: metasystem_module_list invalid type $type" >&2
			return 1
			;;
	esac

	echo $result
}

function metasystem_module_load()
{
	local module=$1
	local ret=0
	shift
	local opt_quiet=
	local opt_force=
	for token in "$@"; do
		case $token in
			-q | -quiet | --quiet)
				opt_quiet=yes
				;;
			-f | -force | --force)
				opt_force=yes
				;;
		esac
	done

	local first_load=yes
	$(metasystem_module_loaded $module) && first_load=

	if [[ -z $first_load && $opt_force != yes ]]; then
		echo "Module $module already loaded - skipping"
		ret=1
	else
		local type=core
		[[ -z $(echo $module | grep '^local\.') ]] || type=local
		local dir=$(_metasystem_module_dir $type)

		local module_name=$(echo $module | sed -e 's/^local\.//')

		local script=$dir/$module_name/module.sh
		if [[ -e $script ]]; then
			[[ $opt_quiet != yes ]] && echo "Loading module $module ..."
			source $script
			ret=$?
			if [[ $ret == 0 ]]; then
				METASYSTEM_MODULES_LOADED="$(list_append $module $METASYSTEM_MODULES_LOADED)"
				[[ -n $first_load ]] && _metasystem_module_register_hooks $module_name
			fi
		else
			echo "Error: $module not found" >&2
			ret=1
		fi
	fi

	return $ret
}

# TODO: support modules in metasystem-local
function metasystem_module_list()
{
	local type=$1
	local dir=$(_metasystem_module_dir $type)

	local list=
	for script in $(find $dir -iname module.sh | sed -e "s|$dir/||" | grep -v ^template); do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		local module=$(dirname $script)
		[[ $type != local ]] || module="local.$module"
		list="$(list_append $module $list)"
	done
	echo $list
}

function metasystem_module_loaded()
{
	local module=$1
	[[ -z $(list_contains $module $METASYSTEM_MODULES_LOADED) ]] && return 1
	return 0
}

# Returns a list of modules which should be loaded
# By default, metasystem attempts to load all available modules
# This behaviour can be overridden by specifying one of the following
# environment variables:
# METASYSTEM_MODULES_EXPLICIT
#     Specify a list of modules to load
# METASYSTEM_MODULES_DISABLE
#     Specify modules to be excluded from the list
function metasystem_module_select()
{
	local result="$(metasystem_module_list core) $(metasystem_module_list local)"
	if [[ -n $METASYSTEM_MODULES_EXPLICIT ]]; then
		local list=$result
		result=
		for module in $METASYSTEM_MODULES_EXPLICIT; do
			[[ -n $(list_contains $module $list) ]] &&\
				result=$(list_append $module $result)
		done
	else
		if [[ -n $METASYSTEM_MODULES_DISABLE ]]; then
			for module in $METASYSTEM_MODULES_DISABLE; do
				result=$(list_remove $module $result)
			done
		fi
	fi
	echo $result
}

function metasystem_module_load_all()
{
	local list="$(metasystem_module_select)"

	local module=
	local first=1
	for module in $list; do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		echo -n "$module "
		metasystem_module_load $module -quiet
		local ret=$?
		if [[ $ret == 0 ]]; then
			echo
		else
			echo "(failed)"
		fi
	done

	if [[ -n $METASYSTEM_MODULES_DISABLE ]]; then
		echo -e "\nDisabled:"
		for module in $METASYSTEM_MODULES_DISABLE; do
			echo $module
		done
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

metasystem_module_load_all

