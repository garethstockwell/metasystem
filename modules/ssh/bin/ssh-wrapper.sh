#!/bin/bash

SSH_AGENT_PID=
SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}-${METASYSTEM_OS}-${METASYSTEM_PLATFORM}"
[[ -f $SSH_AGENT_ENV ]] && source $SSH_AGENT_ENV
ssh_exe=/bin/ssh
[[ $OS != Windows_NT ]] && ssh_exe=$(which ssh)
$ssh_exe "$@"

