# metasystem/shell/modules.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_module_load()
{
	local module=$1
	local quiet=
	[[ $2 == '-quiet' ]] && quiet=1
	local script=$METASYSTEM_ROOT/modules/$module/module.sh
	if [[ -e $script ]]; then
		if [[ -z $quiet ]]; then
			echo "Loading module $module ..."
		fi
		source $script
	else
		echo "Error: $module not found" >&2
		return 1
	fi
}

function metasystem_module_load_all()
{
	local first=1
	for script in $(find $METASYSTEM_ROOT/modules -iname module.sh | sed -e "s|$METASYSTEM_ROOT/modules/||" | grep -v ^template); do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		local module=$(dirname $script)
		echo -n $module
		if [[ -z $(list_contains $module $METASYSTEM_MODULES_DISABLE) ]]; then
			echo
			metasystem_module_load $module -quiet
		else
			echo " (disabled)"
		fi
	done
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

metasystem_module_load_all

