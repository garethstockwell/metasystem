# metasystem/shell/modules.sh

module_first=1

function metasystem_module_load()
{
	local module=$1
	local shrc=$METASYSTEM_ROOT/modules/$module/shell/shrc.sh
	if [[ -e $shrc ]]; then
		echo "Loading module $module ..."
		source $shrc
	else
		echo "Error: module $module not found"
	fi
}

export -f metasystem_module_load

for module in $METASYSTEM_MODULES; do
	[[ -n $module_first ]] && _metasystem_print_banner Modules
	metasystem_module_load $module
	unset module_first
done

unset module_first

