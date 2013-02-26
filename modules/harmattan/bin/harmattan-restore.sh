#!/bin/bash

# http://talk.maemo.org/showthread.php?p=1314911

source $METASYSTEM_CORE_LIB/bash/script.sh

[[ -z $HARMATTAN_BACKUP_ARCHIVE ]] && error "HARMATTAN_BACKUP_ARCHIVE not set"

[[ ! -f $HARMATTAN_BACKUP_ARCHIVE ]] && error "$HARMATTAN_BACKUP_ARCHIVE not found"

echo "About to restore $HARMATTAN_BACKUP_ARCHIVE"
ask "Proceed?" || exit 1

tar -xvpzf $HARMATTAN_BACKUP_ARCHIVE | ssh developer@192.168.2.15 "cat > /"

