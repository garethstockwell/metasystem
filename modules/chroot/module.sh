# modules/chroot/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# http://unix.stackexchange.com/questions/14345/how-do-i-tell-im-running-in-a-chroot

function _metasystem_proc_root_location()
{
	awk '$5=="/" {print $4}' </proc/$1/mountinfo
}

# Returns location of root's / in the host filesystem
function _metasystem_root_location()
{
	_metasystem_proc_root_location $$
}

# Returns true if running in a chroot
function _metasystem_chroot()
{
	[[ $(_metasystem_proc_root_location 1) != $(_metasystem_proc_root_location $$) ]]
}

function _metasystem_hook_chroot_prompt()
{
	_metasystem_chroot || return
	local location=$(_metasystem_root_location)
	ret="${LIGHT_RED}chroot: "
	if [[ -n $SCHROOT_CHROOT_NAME ]]; then
		ret="${ret} ${SCHROOT_CHROOT_NAME} ($location)"
	else
		ret="${ret} $location"
	fi
	ret="${ret}${NO_COLOR}"
	echo $ret
}

function _metasystem_enter_chroot()
{
    local name=$1
    local dir=$2
    local cmd="schroot -c $name -p"
    [[ -n $dir ]] && cmd="$cmd -d $dir"
    echo $cmd
    $cmd
}

