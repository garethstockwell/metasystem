#!/usr/bin/env python

# Script for zipping up contents of repository into an archive for
# distribution

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import os
import os.path
import shutil
import subprocess
import sys
import tempfile
import time

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'release'
        epilog = '''
        Script for releasing the package
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        self.add_argument('repo',
                          metavar='REPO',
                          help='Path to repository')

        # Options
        self.add_argument('-f', '--force',
                          dest='force', default=False,
                          action='store_true',
                          help='ignore errors')
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

def execute(command, args):
    if args.verbose:
        print '\n' + command
    output = []
    if not args.dry_run:
        process = subprocess.Popen(command.split(),
                                   shell=True,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
        while (True):
            line = process.stdout.readline()
            if len(line) == 0:
                break
            output.append(line)
    return output

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
# Main
#------------------------------------------------------------------------------

cwd = os.getcwd()

args = parse_command_line()
if args.verbose:
    print_summary(args)

[head, project_name] = os.path.split(args.repo)
print "Project name = " + project_name

# Check repo is clean
os.chdir(args.repo)
if len(execute("git status", args)) > 4:
    if args.force:
        print "Warning: dirty repo; continuing due to force flag"
    else:
        print "Repo is dirty: commit or clean before re-running"
        exit(1)

# Get SHA1
commit_msg = execute("git log --pretty=oneline", args)[0]
sha = commit_msg.split(' ')[0][0:8]
print "SHA1 = " + sha

# Get timestamp
timestamp = time.strftime('%y%m%d%H%M%S')
print "timestamp = " + timestamp

archivename = project_name + '-' + timestamp + '-' + sha + '.7z'
archivefile = os.path.join(args.repo, '..', archivename)
print "Archive file = " + archivefile

# Create temporary directory
tmpdir = tempfile.mkdtemp()
if args.verbose:
    print "Temporary directory = " + tmpdir
tmprepodir = os.path.join(tmpdir, project_name)

# Copy files
shutil.copytree(args.repo, tmprepodir,
                ignore=shutil.ignore_patterns('.git',
                                              '.cproject',
                                              '.project'))

# Echo tag
tag = open(os.path.join(tmprepodir, '.tag'), 'w')
tag.write(sha + "\n")
tag.close()

# Create archive
os.chdir(tmpdir)
tmparchivefile = os.path.join(tmpdir, archivename)
execute("7z a " + archivefile + ' ' + project_name, args)

# Clean up
os.chdir(cwd)
shutil.rmtree(tmpdir)

