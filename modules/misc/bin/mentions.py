#!/usr/bin/env python

# mentions

# Script for listing items which are mentioned in a series of files
# The original intention for this script was to search for JIRA tasks which
# were mentioned in a series of meeting minutes - in this case, the search
# pattern was r'(SW-\d+)'


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import logging
import re


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80


#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'mentions'
        epilog = '''
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Positional arguments
        self.add_argument('pattern',
                          metavar='PATTERN',
                          help='Pattern')
        self.add_argument('files',
                          metavar='FILES',
                          nargs='+',
                          help='Input files')

        # Options
        self.add_argument('--debug',
                          dest='debug', default=False,
                          action='store_true',
                          help='show debugging output')
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
# Utility functions
#------------------------------------------------------------------------------

def print_error(message):
    print >> sys.stderr, 'Error:', message


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
    print '-' * LINE_WIDTH
    print 'Summary of options'
    print '-' * LINE_WIDTH
    for key in initial_group:
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    for key in sorted(list(set(keys) - set(initial_group))):
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    print '-' * LINE_WIDTH


#------------------------------------------------------------------------------
# Guts
#------------------------------------------------------------------------------

# http://stackoverflow.com/questions/2669059/how-to-sort-alpha-numeric-set-in-python
def sorted_nicely(data):
    convert = lambda text: int(text) if text.isdigit() else text
    alphanum_key = lambda key: [ convert(c) for c in re.split('([0-9]+)', key) ]
    return sorted(data, key = alphanum_key)

def list_file(filename, res, args):
    result = set()
    with open(filename) as f:
        content = f.read()
        for r in res:
            matches = r.findall(content)
            for m in matches:
                result.add(m)
    print '\n\n' + filename
    print '\n'.join(sorted_nicely(result))
    return result


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()

if args.verbose:
    print_summary(args, ('files'))
if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

res = [ ]
res.append(re.compile(args.pattern))

result = set()
for f in args.files:
    result |= list_file(f, res, args)

print "\n\nResult"
print '\n'.join(sorted_nicely(result))

