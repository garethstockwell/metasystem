#!/bin/bash

SSH_AGENT_PID=
SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}-${METASYSTEM_OS}-${METASYSTEM_PLATFORM}"
[[ -f $SSH_AGENT_ENV ]] && source $SSH_AGENT_ENV
/bin/ssh "$@"

