#!/bin/bash

SSH_AGENT_PID=
SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}"
[[ -f $SSH_AGENT_ENV ]] && source $SSH_AGENT_ENV
/bin/ssh "$@"

