#!/bin/bash

# Script for editing the TODO-CLI.txt file

if [ "$1" == "usage" ]
then
    echo "    edit"
    echo "      Edit raw todo.txt file"
else
    cd $TODO_DIR &&
    $TODO_EDITOR todo.txt &&\
    todo.sh ls
fi

