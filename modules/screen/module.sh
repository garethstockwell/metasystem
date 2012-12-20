# modules/screen.sh

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

_metasystem_screen_title=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function screen_set_title()
{
	_metasystem_screen_title="$@"
    echo -en '\033k'$_metasystem_screen_title'\033\\'
}


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_screen_cd_post_hook()
{
	local title=$METASYSTEM_DIRINFO_LABEL
	[[ -z $title ]] && title=shell
	if [[ $title != $_metasystem_screen_title ]]; then
		screen_set_title $title
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# First load only
$(metasystem_module_loaded screen) ||\
	metasystem_register_cd_post_hook _metasystem_screen_cd_post_hook

