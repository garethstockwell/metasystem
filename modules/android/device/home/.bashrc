# bashrc

#------------------------------------------------------------------------------
# Home
#------------------------------------------------------------------------------

# Bomb out from non-interactive shells
[[ $- != *i* ]] && return

# Ensure that we start in the home directory
cd $HOME


#------------------------------------------------------------------------------
# Welcome
#------------------------------------------------------------------------------

echo "Hostname .................... $HOSTNAME"
#echo "User ........................ $(whoami)"


#------------------------------------------------------------------------------
# Aliases
#------------------------------------------------------------------------------

alias com='history | grep $1'
alias du='du -h'
alias ll='ls -l'            # long listing
alias lx='ls -lX'           # sort by extension
alias lk='ls -lSr'          # sort by size
alias la='ls -Al'           # show hidden files
alias lr='ls -lR'           # recursive ls
alias lt='ls -ltr'          # sort by date


#------------------------------------------------------------------------------
# Development
#------------------------------------------------------------------------------

function get_pid()
{
	local match=
	ps | grep $1 | grep -v grep | while read line; do
		if [[ -n $match ]]; then
			echo "Error: '$1' matches multiple processes" >&2
			ps | grep $1 | grep -v grep >&2
			return 1
		fi
		echo $line | awk '{ print $1 }'
		match=1
	done
}

function list_libraries()
{
	if [[ -z $1 ]]; then
		echo "Usage: list_libraries <pid>" >&2
		return 1
	fi
	local pid=$(echo $1 | grep -E '^[0-9]+$')
	[[ -z $pid ]] && pid=$(get_pid $1)
	if [[ $? == 0 ]]; then
		echo "PID ............... $pid"
		echo "Command ........... $(cat /proc/$pid/cmdline)"
		echo "Libraries:"
		pmap $pid | awk '{ print $4 }' | grep \\.so | uniq | sort
	fi
}


#------------------------------------------------------------------------------
# PATH
#------------------------------------------------------------------------------

export PATH=/data/bin:$PATH

