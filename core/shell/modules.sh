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

function metasystem_module_load()
{
	local module=$1
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
		return 1
	fi

	local script=$METASYSTEM_ROOT/modules/$module/module.sh
	if [[ -e $script ]]; then
		[[ $opt_quiet != yes ]] && echo "Loading module $module ..."
		source $script
		METASYSTEM_MODULES_LOADED="$(list_append $module $METASYSTEM_MODULES_LOADED)"
		[[ -n $first_load ]] && _metasystem_module_register_hooks $module
	else
		echo "Error: $module not found" >&2
		return 1
	fi
}

function metasystem_module_list()
{
	local list=
	for script in $(find $METASYSTEM_ROOT/modules -iname module.sh | sed -e "s|$METASYSTEM_ROOT/modules/||" | grep -v ^template); do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		local module=$(dirname $script)
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

function metasystem_module_load_all()
{
	local list="$(metasystem_module_list)"
	local module=
	for module in $METASYSTEM_MODULES_DISABLE; do
		list=$(list_remove $module $list)
	done

	local first=1
	for module in $list; do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		echo $module
		metasystem_module_load $module -quiet
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

