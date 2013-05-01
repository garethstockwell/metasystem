# functions

function check_does_exist()
{
	local path=$1
	if [[ $opt_dryrun != yes && ! -e $path ]]; then
		error "Path $path does not exist"
	fi
}

function check_does_not_exist()
{
	local path=$1
	local r=0
	if [[ $opt_dryrun != yes ]]; then
		if [[ -e $path ]]; then
			if [[ $opt_force != yes ]]; then
				ask "Path $path exists - remove?" || r=1
			fi
			[[ $r = 0 ]] && execute rm -rf $path
		fi
	fi
	return $r
}

