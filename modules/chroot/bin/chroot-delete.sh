#!/bin/bash

# chroot-delete


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_NAME=chroot-delete

SCRIPT_VERSION=0.1

# Arguments
SCRIPT_ARGUMENTS='name'

CHROOT_DIR=/var/chroot
SCHROOT_DIR=/var/lib/schroot


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

METASYSTEM_CORE_LIB_BASH=$HOME/git/github/metasystem/core/lib/bash
source $METASYSTEM_CORE_LIB_BASH/misc.sh
source $METASYSTEM_CORE_LIB_BASH/script.sh


#------------------------------------------------------------------------------
# Options
#------------------------------------------------------------------------------

opt_force=no


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
    cat << EOF
$USAGE_HEADER

Arguments:
    name                    Chroot name

$USAGE_STANDARD_OPTIONS

    -f, --force             Do not prompt

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
            -f | -force | --force)
                opt_force=yes
                ;;

            # Unrecognized options
            -*)
                warn "Unrecognized option '$token' ignored"
                ;;

            # Normal arguments
            *)
                handle_arg $token
                ;;
        esac
    done

    check_sufficient_args
}

function print_summary()
{
    print_standard_summary
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

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity == verbose ]] && print_summary

chroot_dir=$CHROOT_DIR/$arg_name

[[ $opt_force == yes ]] || ask "Remove $chroot_dir" || exit 0

print_banner 'Unmounting filesystems'

for dir in proc sys; do
    mount_point=$chroot_dir/$dir
    echo -n "$mount_point ... "
    if [[ -z $(mount | awk '{ print $3 }' | sort | uniq | grep $mount_point) ]]; then
        echo "not mounted"
    else
        echo
        sudo umount -l $mount_point
    fi
done

schroot_mounts=$(mount | awk '{ print $3 }' | grep $SCHROOT_DIR/mount/$chroot_name)
for mount_point in $schroot_mounts; do
    echo "$mount_point ..."
    sudo umount -l $mount_point
done

echo "Sleeping to allow lazy unmounts to complete ..."
sleep 2

print_banner 'Deleting chroot'
execute sudo rm -rf $chroot_dir

