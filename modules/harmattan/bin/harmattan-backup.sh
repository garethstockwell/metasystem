#!/usr/bin/env bash

# http://talk.maemo.org/showthread.php?p=1314911

source $METASYSTEM_CORE_LIB/bash/script.sh

[[ -z $HARMATTAN_BACKUP_ARCHIVE ]] && error "HARMATTAN_BACKUP_ARCHIVE not set"

rm -fv $HARMATTAN_BACKUP_ARCHIVE

EXCLUDES='proc lost+found sys mnt media dev'

cmd="tar cvzp -"
for e in $EXCLUDES; do
	cmd="$cmd --exclude='$e'"
done
cmd="$cmd /"

echo $cmd

time ssh developer@192.168.2.15 "$cmd" | cat > $HARMATTAN_BACKUP_ARCHIVE

