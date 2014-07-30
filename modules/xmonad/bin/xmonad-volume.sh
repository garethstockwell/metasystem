#!/usr/bin/env bash

# Adapted from https://raw.githubusercontent.com/r0man/dotfiles/master/xmonad/.xmonad/volume.sh

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

# 5% volume change = 3276
FULL=65536
VALUE=3276
SINK=0


#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

opt_verbose=no
opt_level=no
arg_action=


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function update_pct()
{
    curr_vol_pct=$(expr 100 \* $curr_vol_dec / $FULL)
}

function get_state()
{
    curr_vol_hex=$(pacmd dump |grep set-sink-volume | sed 's/.* //g')
    curr_mute=$(pacmd dump | grep set-sink-mute | sed 's/.* //g')
    curr_vol_dec=$(printf '%d\n' $curr_vol_hex)
    update_pct
}

function print_state()
{
    echo -n "$curr_vol_dec (${curr_vol_pct}%"
    [[ $curr_mute != yes ]] || echo -n ', mute'
    echo ')'
}

function set_mute()
{
    mute=$1

    if [[ $mute == yes ]]; then
        pactl set-sink-mute $SINK 1
    else
        pactl set-sink-mute $SINK 0
    fi

    curr_mute=$mute
}

function set_vol()
{
    local vol=$1

    if (( $vol >= 0 )); then
        if (( $vol >= $FULL )); then
            vol=$FULL
        fi
    else
        vol=0
    fi

    pactl set-sink-volume $SINK $vol

    [[ $vol == 0 ]] || set_mute no

    curr_vol_dec=$vol
    update_pct
}

function parse_command_line()
{
    for token in "$@"; do
        case $token in
            -v | -verbose | --verbose)
                opt_verbose=yes
                ;;

            -l | -level | --level)
                opt_level=yes
                ;;

            -*)
                echo "Warning: ignoring unrecognised option $token" >&2
                ;;

            *)
                if [[ -z $arg_action ]]; then
                    arg_action=$token
                else
                    echo "Warning: ignoring unrecognised argument $token" >&2
                fi
                ;;
        esac
    done
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line "$@"

get_state

[[ $opt_verbose != yes ]] || print_state

CHANGE=

# No more than 100%
if [[ $arg_action == up ]]; then
    set_vol $(expr $curr_vol_dec + $VALUE)
    CHANGE=yes
elif [[ $arg_action == down ]]; then
    set_vol $(expr $curr_vol_dec + $VALUE \* -1)
    CHANGE=yes
elif [[ $arg_action == mute ]]; then
    if [[ $curr_mute == yes ]]; then
        set_mute no
    else
        set_mute yes
    fi
    CHANGE=yes
fi

[[ $opt_level != yes ]] || echo $curr_vol_pct

[[ -z $CHANGE || $opt_verbose != yes ]] || print_state

