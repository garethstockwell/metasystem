#!/usr/bin/env python

# Script for testing commandsocket module

import logging
import os
import sys

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
from metasystem import commandsocket

def do_client(args):
    msg = ' '.join(args)
    print "Client: sending '" + msg + "'"
    client = commandsocket.Client()
    reply = client.send(msg)
    print "Reply: '" + reply + "'"

def do_server():
    server = commandsocket.Server()
    while True:
        msg = server.get_message()
        print "Server: message '" + msg.msg + "'"
        msg.send_reply('OK')

logging.getLogger().setLevel(logging.DEBUG)

if len(sys.argv) > 1 and sys.argv[1] == '--server':
    do_server()
else:
    do_client(sys.argv[1:])

