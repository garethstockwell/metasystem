#!/usr/bin/env bash

if [[ $METASYSTEM_PLATFORM == mingw ]]; then
	agent_env=${HOME}/.ssh/agent-env-${HOSTNAME}-windows-cygwin
	[[ -e $agent_env ]] && source $agent_env
	[[ -n $SSH_AUTH_SOCK ]] && export SSH_AUTH_SOCK=/c/cygwin/$SSH_AUTH_SOCK
fi

$METASYSTEM_CORE_BIN/rsync.py "$@"

