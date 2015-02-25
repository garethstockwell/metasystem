#!/bin/bash

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_NAME=alarm

SCRIPT_VERSION=0.1

SCRIPT_ARGUMENTS='time msg'


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

LIB=$(builtin cd $(dirname $0)/../lib/bash && pwd)

source $LIB/script.sh


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

opt_wall=yes
opt_notify=yes


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
    cat << EOF
$USAGE_HEADER

$USAGE_STANDARD_OPTIONS

EOF
}

function parse_command_line()
{
    eval set -- $unused_args

    for token in "$@"; do
        # If the previous option needs an argument, assign it.
        if [[ -n "$prev" ]]; then
            eval "$prev=\$token"
            prev=
            continue
        fi

        optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

        case $token in
            -notify=* | --notify=*)
                opt_notify=$optarg
                ;;

            -notify | --notify)
                prev=opt_notify
                ;;


            -w=* | -wall=* | --wall=*)
                opt_wall=$optarg
                ;;

            -w | -wall | --wall)
                prev=opt_wall
                ;;

            # Unrecognized options
            -*)
                echo "Unrecognized option: $token" >&2
                ;;

            # Normal arguments
            *)
                handle_arg "$token"
                ;;
        esac
    done

    check_sufficient_args
}

function print_summary()
{
    print_standard_summary

    cat << EOF

Wall .................................... $opt_wall
Notify .................................. $opt_notify
EOF
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
    args="$args \"$arg\""
done

parse_standard_arguments $args
parse_command_line

script_preamble

if [[ $opt_dryrun != yes ]]; then
    echo "echo \"alarm: $arg_msg\" | wall" | at $arg_time
    echo "notify-send alarm \"$arg_msg\"" | at $arg_time
fi

