# misc.sh

# Various utility functions

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

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

# Check that the specified path is a valid Linux rootfs
function check_rootfs()
{
	local rootfs=$1
	[[ -z $rootfs ]] && error "No rootfs specified"
	[[ ! -d $rootfs ]] && error "rootfs directory '$rootfs' not found"
	[[ ! -e $rootfs/sbin/init ]] && error "Invalid rootfs $rootfs: /sbin/init not found"
}

