#!/bin/bash

stopped=$(docker ps -aq)
if [[ -n $stopped ]]; then
    echo 'Removing stopped docker containers'
    docker rm $stopped
fi

dangling=$(docker images -qf dangling=true)
if [[ -n $dangling ]]; then
    echo 'Removing dangling docker images'
    docker rmi $dangling
fi

