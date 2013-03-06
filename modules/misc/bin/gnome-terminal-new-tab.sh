#!/usr/bin/env bash

# http://gleamynode.net/articles/2236

GNOME_TERMINAL=$(which gnome-terminal)

pgrep -u "$USER" gnome-terminal | grep -qv "$$"
if [ "$?" == "0" ]; then
	WID=`xdotool search --class "gnome-terminal" | head -1`
	xdotool windowfocus $WID
	xdotool key ctrl+shift+t
	wmctrl -i -a $WID
	if [[ -n $@ ]]; then
		xdotool type "$@"
		xdotool key KP_Enter
	fi
else
	$GNOME_TERMINAL
fi

