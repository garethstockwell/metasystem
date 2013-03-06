#!/usr/bin/env bash

# Script for synchronising the TODO-CLI.txt file

if [ "$1" == "usage" ]
then
	echo "    sync"
	echo "      Synchronise TODO database"
else
	sync.py todo -q &&\
	echo &&\
	todo.sh ls
fi

