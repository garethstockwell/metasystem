#!/usr/bin/env python

import sys
import socket

def domain():
    return socket.getfqdn().replace(socket.gethostname()+'.', '')

def fqdn():
    return socket.getfqdn()

def hostname():
    return socket.gethostname()

import platform
if platform.system() == 'Linux':
    import subprocess
    import re

    def ip():
        import os
        with open(os.devnull, 'w') as null:
            child = subprocess.Popen(['ifconfig'], shell=True,
                                     stdout=subprocess.PIPE,
                                     stderr=null)
            regex = re.compile(r'.*inet addr:(.*?) .*')
            out, err = child.communicate()
            for line in out.split('\n'):
                m = regex.match(line)
                if m:
                    return m.groups()[0]
            return ''

else:
    def ip():
        return socket.gethostbyname(socket.gethostname())

if sys.argv[1] == 'domain':
    print domain()

if sys.argv[1] == 'fqdn':
    print fqdn()

if sys.argv[1] == 'hostname':
    print hostname()

if sys.argv[1] == 'ip':
    print ip()


