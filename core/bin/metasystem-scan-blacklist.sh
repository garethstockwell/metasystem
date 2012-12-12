#!/bin/bash

# Check for existence of blacklisted words in the repository
# Note that lib/git-hooks/post-commit.py performs the same check prior
# to accepting a commit.

ruler='-------------------------------------------------------------------------------'

dir=$1
[[ -z $dir ]] && dir=$METASYSTEM_CORE_ROOT
echo -e "Scanning $dir ... \n"
builtin cd $dir

words=
blacklist=$METASYSTEM_CORE_CONFIG/blacklist.txt
if [[ -e $blacklist ]]; then
	while read line; do
		line=$(echo $line | sed -e 's/#.*//')
		[[ -n $line ]] && words="$words $line"
	done < $blacklist
fi

for word in $words; do
	echo -e "\n$ruler\n$word\n$ruler\n"
	grep -i $word $(find . -type f | grep -v .git)
done

