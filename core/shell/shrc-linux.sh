# shrc-linux.sh

#------------------------------------------------------------------------------
# Ubuntu
#------------------------------------------------------------------------------

if [[ -n `grep 'Ubuntu' /etc/issue 2>/dev/null` ]]; then
	alias ag='sudo apt-get'
	alias agi='sudo apt-get install --yes'
fi

if [[ -n `grep 'Ubuntu 11' /etc/issue 2>/dev/null` ]]; then
	# Work around Unity bug
	alias gvim='gvim -f'
fi

[[ -d /opt/java/x86_64 ]] && export JAVA_HOME=/opt/java/x86_64

