#!/bin/bash

# http://talk.maemo.org/showthread.php?p=1314911

source $METASYSTEM_CORE_LIB/bash/script.sh

[[ -z $HARMATTAN_BACKUP_ARCHIVE ]] && error "HARMATTAN_BACKUP_ARCHIVE not set"

rm -fv $HARMATTAN_BACKUP_ARCHIVE

ssh developer@192.168.2.15 "tar cvzp - --exclude='/proc' --exclude='/lost+found' --exclude='/sys' --exclude='/mnt' --exclude='/media' --exclude='/dev' /" | cat > $HARMATTAN_BACKUP_ARCHIVE

