#!/usr/bin/env python

# netconf-server

# Script which broadcasts a system's network configuration (IP address, MAC
# address, etc) via UDP multicast.

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import os
import sys

sys.path.append(os.path.join(os.path.dirname(
        sys.argv[0]), os.pardir, 'lib', 'python'))

import argparse
import logging

import metasystem
from metasystem import daemon
from metasystem import network
from metasystem import script


#------------------------------------------------------------------------------
# ArgumentParser
#------------------------------------------------------------------------------

class ArgumentParser(daemon.ArgumentParser):

    def __init__(self):

        description = 'metasystem network configuration server'
        version = '0.1'

        daemon.ArgumentParser.__init__(self,
                                       description = description,
                                       version = version)

        self.add_argument('--cookie',
                          dest='cookie',
                          default=None,
                          help='cookie to append to network config structure')


#------------------------------------------------------------------------------
# Program
#------------------------------------------------------------------------------

class Program(daemon.Program):

    def __init__(self):

        super(Program, self).__init__(ArgumentParser())
        self.daemon_info = daemon.Info('metasystem-netconf-server')


    def do_init(self):

        logging.info("do_init")

        if self.args.cookie is None:
            self.args.cookie = network.fqdn()

        logging.debug('cookie = {0:s}'.format(str(self.args.cookie)))

        self.server = network.NetworkConfigServer(cookie=self.args.cookie)
        self.server.init()


    def do_run(self):

        logging.info("do_run")
        self.server.listen()


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

p = Program()
p.run()

