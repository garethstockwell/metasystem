#!/usr/bin/env python

# apply-license-header

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import argparse
import os
import re

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80

EXAMPLE_HEADER = '''// Copyright (c) ACME Ltd'''

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'apply-nsl-header'
        epilog = '''
        Script for applying license headers
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        self.add_argument('license',
                          metavar='LICENSE',
                          help='License')
        self.add_argument('filename',
                          metavar='FILENAME',
                          help='Filename')

        # Options
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-v', '--verbose',
                          dest='verbose', default=False,
                          action='store_true',
                          help='produce verbose output')
        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

#------------------------------------------------------------------------------
# The guts
#------------------------------------------------------------------------------

HEADER_DICT = {
    'example': EXAMPLE_HEADER
}

def process_file(args):
    header = HEADER_DICT.get(args.license)
    if not header:
        print("Invalid licence '" + args.license + "' - valid keys are " + str(HEADER_DICT.keys()))
        raise IOError
    tmp = args.filename + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    os.rename(args.filename, tmp)
    fin = open(tmp, "r")
    fout = open(args.filename, "w")
    [filepath, filename] = os.path.split(args.filename)
    header = header.replace('FILENAME', filename)
    fout.write(header)
    in_header = False
    found_header = False
    for line in fin:
        stripped_line = line.strip()
        if not found_header and stripped_line.startswith("/*"):
            in_header = True
            found_header = True
        if not in_header:
            fout.write(line)
        if stripped_line.endswith("*/"):
            in_header = False
    fin.close()
    os.remove(tmp)


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def print_error(message):
    print('Error:', message, file=sys.stderr)

def parse_command_line():
    '''
    Return: argparse.Namespace
    '''
    parser = ArgumentParser()
    return parser.parse_args()

def print_summary(args, *initial_group):
    '''
    Print results of parsing command line
    Second argument indicates which values should be displayed at the top of
    the list.  These should typically be the destination variables for the
    positional parameters.
    '''
    keys = [name for name in dir(args) if not name.startswith('_')]
    maxkeylen = max([len(key) for key in keys])
    maxvaluelen = max([len(str(getattr(args, key))) for key in keys])
    rightcolpos = LINE_WIDTH - maxvaluelen - 2
    print('-' * LINE_WIDTH)
    print('Summary of options')
    print('-' * LINE_WIDTH)
    for key in initial_group:
        print(' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key))
    for key in sorted(list(set(keys) - set(initial_group))):
        print(' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key))
    print('-' * LINE_WIDTH)

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()
if args.verbose:
    print_summary(args, ('license', 'filename'))
process_file(args)

