#!/usr/bin/env python

from __future__ import print_function

import os
import sys

sys.path.append(os.path.join(os.path.dirname(
        sys.argv[0]), os.pardir, 'lib', 'python'))

from metasystem import network

if len(sys.argv) > 1:
    if sys.argv[1] == 'domain':
        print(network.domain())

    if sys.argv[1] == 'fqdn':
        print(network.fqdn())

    if sys.argv[1] == 'hostname':
        print(network.hostname())

    if sys.argv[1] == 'ip':
        print(network.ip_addr())

