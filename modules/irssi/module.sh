# modules/irssi/module.sh

#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

command_exists irssi || return 1


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

IRSSI_TMUX_SESSION=irssi
IRSSI_TMUX_WINDOW=${IRSSI_TMUX}:1
IRSSI_TMUX_WINDOW=${IRSSI_TMUX}:1

function irssi_nickpane() {
    local session=$1
    [[ -z $session ]] || session=${session}:
    local window=${session}1
    local pane=${window}.1
    echo window=${window}
    echo pane=${pane}

    tmux split-window -h -l 20 "cat ~/.irssi/nicklistfifo"
    tmux send-keys -t ${pane} "/nicklist fifo" C-m
    tmux select-pane ${pane}
}

function irssi_naked() {
    irssi_nickpane
    $(which irssi)
}

function irssi_tmux() {
    if ! tmux -L default attach-session -t ${IRSSI_TMUX_SESSION} 2>/dev/null; then
        tmux new-session -d -s ${IRSSI_TMUX_SESSION} irssi
        irssi_nickpane ${IRSSI_TMUX_SESSION}
        tmux attach -t ${IRSSI_TMUX_SESSION}
    fi
}

function irssi_install() {
    mkdir -p ~/.irssi/scripts/autorun

    pushd ~/.irssi/scripts
    curl -O https://scripts.irssi.org/scripts/adv_windowlist.pl
    curl -O https://scripts.irssi.org/scripts/hilightwin.pl
    curl -O https://scripts.irssi.org/scripts/nicklist.pl
    curl -O https://scripts.irssi.org/scripts/usercount.pl
    popd

    pushd ~/.irssi/scripts/autorun
    ln -sf ../*.pl .
    popd
}

function irssi() {
    if [[ -z $TMUX ]]; then
        irssi_tmux
    else
        irssi_naked
    fi
}

function irssi_repair() {
    tmux selectw -t irssi
    tmux selectp -t 0
    tmux killp -a
    irssi_nickpane
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

#export METASYSTEM_IRSSI_ROOT=$( builtin cd "$( dirname "${BASH_SOURCE:-$0}" )" && pwd )


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

