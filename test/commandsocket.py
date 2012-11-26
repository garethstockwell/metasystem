#!/usr/bin/env python

# Script for testing CommandSocket module

import logging
import os
import sys

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
import CommandSocket

def do_client(args):
    msg = ' '.join(args)
    print "Client: sending '" + msg + "'"
    client = CommandSocket.Client()
    reply = client.send(msg)
    print "Reply: '" + reply + "'"

def do_server():
    server = CommandSocket.Server()
    while True:
        msg = server.get_message()
        print "Server: message '" + msg.msg + "'"
        msg.send_reply('OK')

logging.getLogger().setLevel(logging.DEBUG)

if len(sys.argv) > 1 and sys.argv[1] == '--server':
    do_server()
else:
    do_client(sys.argv[1:])

