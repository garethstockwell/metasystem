#!/usr/bin/env bash

# Connects to existing screen on remote server, if existing.
# Otherwise starts a new screen.

$METASYSTEM_ROOT/modules/ssh/bin/ssh-wrapper.sh -Y -t "$@" screen -RR

