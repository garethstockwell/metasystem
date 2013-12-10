# modules/chroot/module.sh

#------------------------------------------------------------------------------
# Preconditions
#------------------------------------------------------------------------------

[ $METASYSTEM_OS == 'linux' ] || return 1


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# http://unix.stackexchange.com/questions/14345/how-do-i-tell-im-running-in-a-chroot

function _metasystem_proc_root_location()
{
	if [[ -e /proc/$1/mountinfo ]]; then
		awk '$5=="/" {print $4}' </proc/$1/mountinfo
	fi
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

#function _metasystem_hook_chroot_prompt()
#{
#	_metasystem_chroot || return
#	echo "${LIGHT_RED}chroot: $(chroot_desc)${NO_COLOR}"
#}

function _metasystem_enter_chroot()
{
    local name=$1
    local dir=$2
    local cmd="schroot -c $name -p"
    [[ -n $dir ]] && cmd="$cmd -d $dir"
    echo $cmd
    $cmd
}

function chroot_name()
{
	if [[ -n $SCHROOT_CHROOT_NAME ]]; then
		echo $SCHROOT_CHROOT_NAME
	fi
}

function chroot_location()
{
	if [[ _metasystem_chroot ]]; then
		_metasystem_root_location
	fi
}

function chroot_desc()
{
	local name=$(chroot_name)
	local location=$(chroot_location)
	if [[ -n $name ]]; then
		echo "$name@$location"
	else
		echo $location
	fi
}

