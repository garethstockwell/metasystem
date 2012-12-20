# modules/ssh-agent.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}-${METASYSTEM_OS}-${METASYSTEM_PLATFORM}"

function ssh_agent_pid()
{
	if [[ -n ${SSH_AGENT_PID} ]]; then
		ps -ef | grep $SSH_AGENT_PID | grep ssh-agent$ > /dev/null
		[[ $? == 0 ]] && echo $SSH_AGENT_PID
	fi
}

function ssh_agent_start()
{
	echo -n "Starting ssh-agent ... "
	local pid=$(ssh_agent_pid)
	if [[ -n $pid ]]; then
		echo "already active PID $pid"
	else
		rm -f ${SSH_AGENT_ENV}
		ssh-agent | sed 's/^echo/#echo/' > ${SSH_AGENT_ENV}
		chmod 600 "${SSH_AGENT_ENV}"
		export SSH_AGENT_PID=
		source ${SSH_AGENT_ENV} > /dev/null
		if [[ -n $SSH_AGENT_PID ]]; then
			echo "PID $SSH_AGENT_PID"
			ssh-add
		else
			echo "failed"
		fi
	fi
}

function ssh_agent_stop()
{
	echo "Stopping ssh-agent ..."
	local pid=$(ssh_agent_pid)
	[[ -n $pid ]] && kill -9 $pid
	rm -f ${SSH_AGENT_ENV}
}

function metasystem_ssh_agent_init()
{
	_metasystem_print_banner "ssh-agent"
	[[ -f ${SSH_AGENT_ENV} ]] && source ${SSH_AGENT_ENV} > /dev/null
	ssh_agent_start
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

metasystem_register_init_hook metasystem_ssh_agent_init


