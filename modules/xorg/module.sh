# modules/xorg.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists X || return 1


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function _x_window_type()
{
    grep _NET_WM_WINDOW_TYPE | cut -d_ -f10
}

function x_window_type()
{
	xprop | _x_window_type
}

function _x_window_role()
{
	grep WM_WINDOW_ROLE | cut -d\" -f2
}

function x_window_role()
{
	xprop | _x_window_role
}

function _x_window_class_name()
{
	grep WM_CLASS | cut -d\" -f2
}

function x_window_class_name()
{
	xprop | _x_window_class_name
}

function _x_window_class()
{
	grep WM_CLASS | cut -d\" -f4
}

function x_window_class()
{
	xprop | grep _x_window_class
}

function _x_window_title()
{
	grep WM_NAME | grep UTF8 | cut -d\" -f2
}

function x_window_title()
{
	xprop | _x_window_title
}

function x_prop()
{
	local out="$(xprop)"

	local type=$(echo "$out" | _x_window_type)
	local role=$(echo "$out" | _x_window_role)
	local class_name=$(echo "$out" | _x_window_class_name)
	local class=$(echo "$out" | _x_window_class)
	local title=$(echo "$out" | _x_window_title)

	echo "$out"
	echo
	echo "Type:        $type"
	echo "Role:        $role"
	echo "Class name:  $class_name"
	echo "Class:       $class"
	echo "Title:       $title"
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

