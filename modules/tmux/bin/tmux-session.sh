#!/bin/bash

name=$1
if [[ -z $name ]]; then
	name=default
fi

tmux has-session -t $name
if tmux has-session -t $name 2>/dev/null; then
	tmux attach -t $name
else
	tmux new-session -s $name
fi

