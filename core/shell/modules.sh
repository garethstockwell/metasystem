# metasystem/shell/modules.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_module_load()
{
	local module=$1
	local quiet=
	[[ $2 == '-quiet' ]] && quiet=1
	local file=$METASYSTEM_ROOT/modules/$module.sh
	local dir=$METASYSTEM_ROOT/modules/$module
	[[ ! -f $METASYSTEM_ROOT/modules/$module.sh ]] && unset file
	[[ ! -d $METASYSTEM_ROOT/modules/$module ]] && unset dir
	if [[ -n $file && -n $dir ]]; then
		echo "Error: $module is ambiguous" >&2
		return 1
	fi
	if [[ -z $file && -z $dir ]]; then
		echo "Error: $module not found" >&2
		return 1
	fi
	local script=$file
	[[ -n $dir ]] && script=$dir/module.sh
	if [[ -z $quiet ]]; then
		echo "Loading module $module ..."
	fi
	source $script
}

function metasystem_module_load_all()
{
	local first=1
	for entry in $('ls' $METASYSTEM_ROOT/modules | grep -v ^templates); do
		[[ -n $first ]] && _metasystem_print_banner Modules
		unset first
		local module=${entry/.sh/}
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

