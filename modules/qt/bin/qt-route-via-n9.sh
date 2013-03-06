#!/usr/bin/env bash

# Route SSH port 29418 via the N9, to work around corporate firewall

LOCAL_PORT=2000
REMOTE_PORT=codereview.qt-project.org:29418

echo "Routing localhost:$LOCAL_PORT -> $REMOTE_PORT ..."
ssh -f developer@n9 -L $LOCAL_PORT:$REMOTE_PORT -N

echo "Now you can push to gerrit using e.g."
echo "git push ssh://gastockw@localhost:$LOCAL_PORT/qt/qtbase HEAD:refs/for/master"

