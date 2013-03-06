#!/usr/bin/env bash

# start_commit=1234abcd
# git log --reverse --pretty=oneline $start_commit.. -- my_filename.* | awk '{ print $1 }'
commits=$*
index=0

echo commits=$commits

for c in $commits
do
	(( index++ ))
	git log -1 --pretty=oneline $c
	git format-patch -1 --start-number $index $c
done


