# modules/profile/module.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_profile_update()
{
	local args="--reset --auto all"
	local global=
	for arg in $*
	do
		args="$args --user $arg"
	done

	echo "Setting profile for this shell session"

	local cmd="metasystem-profile.py --verbose set $args"
	echo $cmd

	local lpath=$PATH
	[[ -n $METASYSTEM_SYMBIAN_ROOT ]] && lpath=$(path_remove_epoc $path)

	PATH=$lpath $cmd

	[[ $global != 1 ]] && source ~/.metasystem-profile

	metasystem-id.py generate --script
}

alias profile-get='source ~/.metasystem-profile'
alias profile-print='metasystem-profile.py print'
alias profile='profile-print'
alias profile-update=metasystem_profile_update


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_PROFILE_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_PROFILE_BIN=$METASYSTEM_PROFILE_ROOT/bin


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_hook_profile_init()
{
	_metasystem_print_banner "Profile"
	if [[ -e ~/.metasystem-profile ]]; then
		echo "Sourcing existing .metasystem-profile"
		source ~/.metasystem-profile
	else
		metasystem_profile_update
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_PROFILE_BIN $PATH)

