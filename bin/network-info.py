#!/usr/bin/env python

import socket
import sys

if sys.argv[1] == 'domain':
    print socket.getfqdn().replace(socket.gethostname()+'.', '')
elif sys.argv[1] == 'hostname':
    print socket.gethostname()
elif sys.argv[1] == 'ip':
    print socket.gethostbyname(socket.gethostname())
elif sys.argv[1] == 'fqdn':
    print socket.getfqdn()

