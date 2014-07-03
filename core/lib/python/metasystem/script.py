"""
This module provides base classes and utility functions which can be used to
build command-line programs.
"""


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import logging
import sys

import metasystem
import metasystem.exit


#------------------------------------------------------------------------------
# Globals
#------------------------------------------------------------------------------

dry_run = False
quiet = False
verbose = False
debug = False


#------------------------------------------------------------------------------
# ArgumentParser
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    """
    Argument parser base class

    Handles standard arguments
    """

    def __init__(self, description='',
                       epilog='',
                       version=0.1):

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog,
                                         formatter_class=argparse.ArgumentDefaultsHelpFormatter)

        self.allow_unknown_args = False

        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help="show what would be done, but don't make any changes")

        output = self.add_argument_group('Output')

        output.add_argument('--debug',
                            dest='debug', default=False,
                            action='store_true',
                            help='show debugging output')

        output.add_argument('--log',
                            metavar='FILE',
                            dest='log_file',
                            help='log to specified file')

        verbosity = output.add_mutually_exclusive_group()

        verbosity.add_argument('-v', '--verbose',
                               dest='verbose', default=False,
                               action='store_true',
                               help='show verbose output')

        verbosity.add_argument('-q', '--quiet',
                               dest='quiet', default=False,
                               action='store_true',
                               help='suppress output')


#------------------------------------------------------------------------------
# Program
#------------------------------------------------------------------------------

class Program(object):
    """
    Command line program base class

    Performs common initialization of the runtime environment, required
    by all command-line tools
    """

    def __init__(self, parser):

        Program._exit_handler.add(self)

        self.parser = parser
        self.ok = True


    def init(self, do_init=True):

        logging.init()
        logging.add_console_handler()

        try:
            if self.parser.allow_unknown_args:
                self.args, self.unknown_args = self.parser.parse_known_args()
            else:
                self.args = self.parser.parse_args()
        except metasystem.UsageError as e:
            self.parser.print_help()
            sys.stderr.write('\n' + str(e) + '\n')
            sys.exit(1)

        self.parse_args_post_hook()

        if self.args.log_file:
            logging.add_file_handler(self.args.log_file)

        self.init_globals()

        logging.init_level(quiet=self.args.quiet, debug=self.args.debug)

        if do_init:
            self.do_init()


    def do_init(self):

        pass


    def run(self):

        self.init()
        self.do_run()
        self.exit()


    def exit(self):

        ret = { True: 0, False: 1 }.get(self.ok)
        sys.exit(ret)


    def do_run(self):

        pass


    def parse_args_post_hook(self):

        # Hook to allow derived classes to fiddle with the args structure
        # before proceeding
        pass


    def init_globals(self):

        global dry_run, quiet, debug, verbose
        dry_run = self.args.dry_run
        quiet = self.args.quiet
        debug = self.args.debug
        verbose = self.args.verbose


    def _program_cleanup(self):

        logging.debug('script.Program._program_cleanup')
        self.cleanup()


    def cleanup(self):

        logging.debug('script.Program.cleanup')
        pass


    _exit_handler = metasystem.exit.ExitHandler(_program_cleanup)


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

def print_banner(msg):

    ruler = '-' * 80
    logging.info('')
    logging.info(ruler)
    logging.info(msg)
    logging.info(ruler)


def error(msg, ret=1):

    logging.error(msg)
    sys.exit(ret)

