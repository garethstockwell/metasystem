# Functions used for port forwarding setup

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

# Command executed on the server to generate the base server-sider port number
SSH_PORT_FWD_REMOTE_BASE_CMD='echo 5$(echo $UID 2>/dev/null | tail -c3)00'


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function __ssh_port_fwd_service_name()
{
	local service=$1
	local index=$2
	[[ -n $index ]] && service=${service}$(printf "_%02d" $index)
	echo $service
}

function __ssh_port_fwd_get_field()
{
	local name=$1
	local field=$2
	eval echo \$SSH_PORT_FWD_SERVICE_${name}_${field}
}

function __ssh_port_fwd_local_port()
{
	local remote_port_base=$1
	local service=$2
	local index=$3
	local local_base=$(__ssh_port_fwd_get_field $service local_base)
	if [[ -z $local_base ]]; then
		local local_offset=$(__ssh_port_fwd_get_field $service local_offset)
		local_base=$(( $remote_port_base + $local_offset ))
	fi
	echo $(( local_base + $index-1 ))
}

function __ssh_port_fwd_remote_port()
{
	local remote_port_base=$1
	local service=$2
	local index=$3
	local remote_offset=$(__ssh_port_fwd_get_field $service remote_offset)
	echo $(( $remote_port_base + $remote_offset + $index-1 ))
}

function ssh_port_fwd_list_ports_remote()
{
	local remote_port_base=$1
	echo "   service port"
	for name in $SSH_PORT_FWD_SERVICES; do
		local count=$(__ssh_port_fwd_get_field $name count)
		for index in $(seq 1 $count); do
			local service=$(__ssh_port_fwd_service_name $name $index)
			local remote_port=$(__ssh_port_fwd_remote_port $remote_port_base $name $index)
			printf "%10s %5d\n" $service $remote_port
		done
	done
}

function __ssh_port_fwd_env()
{
	local host=$1
	echo $HOME/.ssh/port-fwd-env-${host}
}

function __ssh_port_fwd_var()
{
	local host=$1
	echo ${host//-/_}
}

function __ssh_port_fwd_pid()
{
	local host=$1
	local env=$(__ssh_port_fwd_env $host)
	if [[ -e $env ]]; then
		source $env > /dev/null
		local pid_var=$(__ssh_port_fwd_var $host)
		local pid=$(eval echo \$$pid_var)
		ps -ef | grep $pid | grep ssh$ > /dev/null
		[[ $? == 0 ]] && echo $pid
	fi
}

function ssh_port_fwd_start()
{
	local host=$1
	echo -n "Starting port forwarding to $host ... "
	local pid=$(__ssh_port_fwd_pid $host)
	if [[ -n $pid ]]; then
		echo "already active PID $pid"
	else
		local env=$(__ssh_port_fwd_env $host)
		rm -f $env
		pid=$(ssh-port-fwd.sh $host --quiet --bg 2>&1)
		if [[ $? == 0 ]]; then
			echo "PID $pid"
			local pid_var=$(__ssh_port_fwd_var $host)
			echo "export ${pid_var}=${pid}" > $env
		else
			echo "failed"
		fi
	fi
}

function ssh_port_fwd_stop()
{
	local host=$1
	local pid=$(__ssh_port_fwd_pid $host)
	if [[ -n $pid ]]; then
		echo "Stopping port forwarding to $host (PID $pid) ... "
		kill -9 $pid
	fi
}

function ssh_port_fwd()
{
	for host in $SSH_PORT_FWD_HOSTS; do
		ssh_port_fwd_start $host
	done
}

