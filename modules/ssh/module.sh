# modules/ssh.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists ssh || return 1
command_exists scp || return 1
command_exists ssh-agent || return 1


#------------------------------------------------------------------------------
# ssh
#------------------------------------------------------------------------------

function ssh()
{
	# Forward X connection
	$(which ssh) -Y $@
}

function ssh_screen()
{
	# Remote screen (detaches if already connected)
	ssh-wrapper.sh -Y -t "$@" "screen -RR"
}

alias ssh-screen=ssh_screen


#------------------------------------------------------------------------------
# scp
#------------------------------------------------------------------------------

# From climagic (with protocol 2 added)
function scp()
{
	if [[ "$@" =~ : ]]; then
		$(which scp) -2 $@
	else
		echo "Error: missing colon" >&2
		return 1
	fi
}


#------------------------------------------------------------------------------
# ssh-agent
#------------------------------------------------------------------------------

SSH_AGENT_ENV="$HOME/.ssh/agent-env-${HOSTNAME}-${METASYSTEM_OS}-${METASYSTEM_PLATFORM}"

function ssh_agent_add_all()
{
	ssh-add $HOME/.ssh/*id_rsa
}

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
			ssh_agent_add_all
		else
			echo "failed"
		fi
	fi
	echo -e "\nKeys added to ssh-agent:"
	ssh-add -l
}

function ssh_agent_stop()
{
	echo "Stopping ssh-agent ..."
	local pid=$(ssh_agent_pid)
	[[ -n $pid ]] && kill -9 $pid
	rm -f ${SSH_AGENT_ENV}
    export SSH_AGENT_PID=
    export SSH_AUTH_SOCK=
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

export METASYSTEM_SSH_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )
export METASYSTEM_SSH_BIN=$METASYSTEM_SSH_ROOT/bin
export METASYSTEM_SSH_LIB=$METASYSTEM_SSH_ROOT/lib


#------------------------------------------------------------------------------
# Hooks
#------------------------------------------------------------------------------

function _metasystem_hook_ssh_init()
{
	_metasystem_print_banner "ssh-agent"
	[[ -f ${SSH_AGENT_ENV} ]] && source ${SSH_AGENT_ENV} > /dev/null
	ssh_agent_start
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

PATH=$(path_append $METASYSTEM_SSH_BIN $PATH)
source $METASYSTEM_SSH_LIB/port-fwd-config.sh
source $METASYSTEM_SSH_LIB/port-fwd.sh

_metasystem_dotfile_register ssh config ssh/config

