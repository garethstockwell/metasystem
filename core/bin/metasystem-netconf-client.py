#!/usr/bin/env python2

# netconf-client

# Script which listens for a system's network configuration (IP address, MAC
# address, etc), broadcat via UDP multicast.

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import os
import sys

sys.path.append(os.path.join(os.path.dirname(
        sys.argv[0]), os.pardir, 'lib', 'python'))

import argparse
import logging

import metasystem
from metasystem import network
from metasystem import script


#------------------------------------------------------------------------------
# ArgumentParser
#------------------------------------------------------------------------------

class ArgumentParser(script.ArgumentParser):

    def __init__(self):

        description = 'metasystem network configuration listener'
        version = '0.1'

        script.ArgumentParser.__init__(self,
                                       description = description,
                                       version = version)

        group = self.add_mutually_exclusive_group()

        group.add_argument('--cookie',
                           metavar='COOKIE',
                           dest='cookie',
                           default=None,
                           help='cookie to append to network config structure')

        group.add_argument('--ip',
                           metavar='FQDN',
                           dest='fqdn',
                           default=None,
                           help='retrieve IP address for specified FQDN')


#------------------------------------------------------------------------------
# Program
#------------------------------------------------------------------------------

class Program(script.Program):

    def __init__(self):

        script.Program.__init__(self, ArgumentParser())


    def do_run(self):

        if self.args.fqdn is not None:
            self.args.cookie = self.args.fqdn

        logging.debug('cookie = {0:s}'.format(str(self.args.cookie)))

        self.client = network.NetworkConfigClient(cookie=self.args.cookie)
        result = self.client.request()

        if self.args.fqdn is not None:
            for entry in result:
                if entry.cookie == self.args.cookie:
                    print(entry.ip_addr)
                    return

            sys.exit(1)

        else:
            msg = 'Received {0:d} configuration'.format(len(result))
            if len(result) != 1:
                msg += 's'
            msg += ':'
            logging.info('\n' + msg)

            for entry in result:
                logging.info('\n' + str(entry))


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

p = Program()
p.run()

