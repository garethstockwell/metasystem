#!/usr/bin/env bash

# Lists all commits which are in a target branch, but not in the current
# branch.
#
# Useful to check before deleting a branch.
#
# TODO: print out subject of commit.  'git show --oneline' is supposed to
# do this, but doesn't work on my machine.

branch=$1
limit=$2

if [ -z "$branch" -o -z "$limit" ]
then
	echo "Usage: $0 <branch> <limit>"
	exit 1
fi

current_branch=`git branch | grep '\*' | sed -e 's/\* / /' | sed -e 's/ //g'`
echo "current = $current_branch"

for commit in `git log -n $limit | grep '^commit' | awk '{print $2}'`
do
	branches=`git branch --contains $commit | sed -e 's/\*/ /g' | sed -e 's/ //g'`

	found=0
	for branch in $branches
	do
		if [ "$branch" == "$current_branch" ]
		then
			found=1
		fi
	done
	if [ "$found" == "0" ]
	then
		echo $commit
	fi
done
