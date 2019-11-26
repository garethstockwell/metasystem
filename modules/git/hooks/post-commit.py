#!/usr/bin/env python2

# check-commit

# Check a GIT commit
#
# Based on the qt-project commit sanitizer (git-hooks/sanitize-commit in
# ssh://codereview.qt-project.org/qt/qtrepotools.git)
#
# This script performs a number of checks.  Each check is associated with two
# pieces of metadata:
#
# key (string)
#     This must be one of the elements of the KEYS array.
#     Its purpose is to group together related checks, and to allow groups of
#     checks to be skipped by setting an environment variable (TODO).
#
# behaviour on failure
#     This can either be to generate a warning, or print an error and abort the
#     commit.
#
# The checks performed are listed below.
#
# +---------------------------------------------------------------------------+
# | Assertion                                              | Key      | Fail  |
# +---------------------------------------------------------------------------+
# | Author email is non-empty                              | email    | Abort |
# +---------------------------------------------------------------------------+
# | Committer email is non-empty                           | email    | Abort |
# +---------------------------------------------------------------------------+
# | Message summary is greater than MIN_SUMMARY_LENGTH     | log      | Abort |
# | characters                                             |          |       |
# +---------------------------------------------------------------------------+
# | Message summary is less than PREF_MAX_SUMMARY_LENGTH   | log      | Warn  |
# | characters                                             |          |       |
# +---------------------------------------------------------------------------+
# | Message summary is less than MAX_SUMMARY_LENGTH        | log      | Abort |
# | characters                                             |          |       |
# +---------------------------------------------------------------------------+
# | Second line of message is blank                        | log      | Abort |
# +---------------------------------------------------------------------------+
# | Line endings are not CRLF                              | crlf     | Abort |
# +---------------------------------------------------------------------------+
# | Merge conflicts are resolved                           | conflict | Abort |
# +---------------------------------------------------------------------------+
# | Spaces are not mixed with TABs                         | style    | Warn  |
# +---------------------------------------------------------------------------+
# | Space indents are not followed by TABs                 | style    | Warn  |
# +---------------------------------------------------------------------------+
# | TAB characters only appear in leading whitespace       | style    | Warn  |
# +---------------------------------------------------------------------------+
# | There is no trailing whitespace                        | style    | Warn  |
# +---------------------------------------------------------------------------+
# | None of the words listed in                            | blacklist| Fail  |
# | $METASYSTEM_CONFIG/blacklist.txt are added by the      |          |       |
# | commit                                                 |          |       |
# +---------------------------------------------------------------------------+


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import argparse
import os
import re
import subprocess
import sys


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

KEYS = ['conflict', 'crlf', 'email', 'log', 'style', 'blacklist']

MIN_SUMMARY_LENGTH = 7
PREF_MAX_SUMMARY_LENGTH = 70
MAX_SUMMARY_LENGTH = 120


#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    '''
    Command line argument parser
    '''
    def __init__(self):
        description = 'check-commit'
        epilog = '''
        GIT commit checker
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Positional arguments
        self.add_argument('sha1',
                          metavar='SHA1',
                          help='SHA1')

        # Options
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-s', '--strict',
                          dest='strict', default=False,
                          action='store_true',
                          help='strict checking')
        self.add_argument('-v', '--verbose',
                          dest='verbose', default=False,
                          action='store_true',
                          help='produce verbose output')
        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")


class CommitCheckResult(object):
    '''
    Result of the commit check
    '''
    def __init__(self, args):
        self.args = args
        self.retval = 0
        self.msgs = []

    def error(self, msg, **kwargs):
        kwargs = process_kwargs(dict(key=None, level=0, \
                                     lineno=None, line=None), kwargs)
        if kwargs['key']:
            assert(kwargs['key'] in KEYS)
        if kwargs['level'] >= 0:
            if kwargs['level'] >= self.retval:
                self.retval = kwargs['level']
            msg = 'Error: ' + msg
        else:
            msg = 'Warning: ' + msg
        if kwargs['lineno']:
            msg += ' at line ' + str(kwargs['lineno'])
        if kwargs['key']:
            msg = msg + ' [key=' + kwargs['key'] + ']'
        if kwargs['lineno']:
            msg = msg + '\n{0}:{1}'.format(kwargs['lineno'], kwargs['line'])
        self.msgs.append(msg)


class CommitChecker(object):
    '''
    Class which performs the commit check
    '''
    def __init__(self, args):
        self._args = args
        self._sha1 = args.sha1
        self._result = CommitCheckResult(args)

        self._skip_keys = []

        self._parse_msg()

        self._check_ws = True
        self._conflict = False
        self._crlf = False
        self._line = ''
        self._lineno = 0
        self._filename = ''
        self._merge = False
        self._style_failures = []
        self._blacklist = []
        self._read_blacklist()
        self._parse_diff()

    def _print_msgs(self):
        if self._filename != '':
            print('\n' + self._filename, file=sys.stderr)
        for msg in self._result.msgs:
            print(msg, file=sys.stderr)

    def retval(self):
        return self._result.retval

    def _error(self, msg, **kwargs):
        if not 'level' in kwargs.keys():
            kwargs['level'] = 1
        self._result.error(msg, **kwargs)

    def _warn(self, msg, **kwargs):
        kwargs['level'] = -1
        self._result.error(msg, **kwargs)

    def _diff_error(self, msg, **kwargs):
        if not 'level' in kwargs.keys():
            kwargs['level'] = 1
        kwargs['lineno'] = self._lineno
        kwargs['line'] = self._line
        self._result.error(msg, **kwargs)

    def _diff_warn(self, msg, **kwargs):
        kwargs['level'] = -1
        kwargs['lineno'] = self._lineno
        kwargs['line'] = self._line
        self._result.error(msg, **kwargs)


    def _parse_msg(self):
        '''
        Parse the git commit message
        '''
        print_if_verbose('\nParsing git commit message for SHA1 '
                         + self._sha1 + ' ...\n', self._args)
        git_output = execute('git log -1 --pretty=raw ' + self._sha1, self._args)
        parents = 0
        lineno = 0
        for line in git_output:
            print_if_verbose(line, self._args)
            stripped = re.sub(r'^    ', '', line)
            if stripped == line:
                if re.match(r'^parent ', line):
                    parents += 1
                elif re.match(r'^author .*\.\(none\)', line):
                    self._error('Bogus author email', 1, key='email')
                elif re.match(r'^committer .*\.\(none\)', line):
                    self._error('Bogus committer email', 1, key='email')
                continue
            line = stripped
            if lineno == 0:
                line_len = len(line)
                if line_len < MIN_SUMMARY_LENGTH:
                    msg = 'Log message summary is too short ({0} chars; minimum' \
                          ' allowed {1})'.format(line_len, MIN_SUMMARY_LENGTH)
                    self._error(msg, key='log')
                elif line_len > MAX_SUMMARY_LENGTH:
                    msg = 'Log message summary is too long ({0} chars; maximum' \
                          ' allowed {1})'.format(line_len, MAX_SUMMARY_LENGTH)
                    self._error(msg, key='log')
                elif parents < 2 and line_len > PREF_MAX_SUMMARY_LENGTH:
                    msg = 'Log message summary is too long ({0} chars; maximum' \
                          ' preferred {1})'.format(line_len, PREF_MAX_SUMMARY_LENGTH)
                    self._warn(msg, key='log')
            else:
                if lineno == 1:
                    if len(line) != 0:
                        self._error('2nd line of log message is not empty', key='log')
            lineno += 1


    def _file_end(self):
        '''
        Called when end of a file is reached while parsing the diff
        '''
        if len(self._style_failures):
            self._warn('Style issues', key='style')
            for msg in self._style_failures:
                self._result.msgs.append(msg)
        self._print_msgs()
        self._filename = ''
        self._style_failures = []


    def _style_fail(self, msg):
        '''
        Called when a style check fails
        '''
        self._style_failures.append('{0}: {1}'.format(self._lineno, msg))


    def _read_blacklist(self):
        try:
            f = open(os.path.join(os.environ.get('METASYSTEM_CONFIG'), 'blacklist.txt'))
            if f:
                for line in f:
                    line = line.rstrip()
                    if not line.startswith('#') and len(line):
                        self._blacklist.append(line)
        except:
            pass


    def _parse_diff(self):
        '''
        Parse the git commit diff
        '''
        print_if_verbose('\nParsing git diff for SHA1 '
                         + self._sha1 + ' ...\n', self._args)
        git_output = execute('git diff-tree --no-commit-id --diff-filter=ACMR \
                              --src-prefix=\@old\@/ --dst-prefix=\@new\@/ --full-index -r \
                              -U100000 --cc -C -l1000 --root ' + self._sha1, self._args)
        for line in git_output:
            self._line = line
            print_if_verbose(line, self._args)
            if re.match(r'^-', line):
                # Line is deletion
                pass

            elif re.match(r'^\+', line):
                # Line is addition
                if re.match(r'^\+\+\+ ', line):
                    # This indicates a text file
                    # Binary files have "Binary files ... and ... differ"
                    continue
                self._lineno += 1
                if self._merge:
                    # Consider only lines which are new relative to both parents,
                    # i.e. were added during the merge
                    stripped = re.sub(r'^\+\+', '', line)
                    if stripped == line:
                        continue
                    line = stripped
                line = re.sub(r'^\+', '', line)
                # Check for blacklisted words
                if not 'blacklist' in self._skip_keys:
                    for word in self._blacklist:
                        if re.match(r'.*\b' + word + r'\b.*', line, re.IGNORECASE):
                            self._diff_error("Blacklisted word '" + word + "' found", key='blacklist')
                if not self._crlf and re.match(r'\r\n$', line) and not 'crlf' in self._skip_keys:
                    self._crlf = True
                    self._diff_error('CRLF line endings', key='crlf')
                if not self._conflict and re.match(r'^(?:[<>=]){7}( |$)', line):
                    self._conflict = True
                    self._diff_error('Unresolved merge conflict', key='conflict')
                if self._check_ws:
                    if re.match(r'^ +\t|\t +', line):
                        self._style_fail('Mixing spaces with TABs')
                    else:
                        if re.match(r'^ +\t', line):
                            self._style_fail('Space indent followed by a TAB character')
                        if re.match(r'\S+\t', line):
                            self._style_fail('TAB character in non-leading whitespace')
                        if re.match(r'[ \t]\r?\n$', line):
                            self._style_fail('Trailing whitespace')
            else:
                # Line is neither deletion nor addition
                if re.match(r'^ ', line):
                    if not self._merge or not re.match(r'^ -', line):
                        self._lineno += 1
                    continue
                if self._merge:
                    m = re.match(r'^\@\@\@ -\S+ -\S+ \+(\d+)', line)
                    if m:
                        self._lineno = int(m.group(1)) - 1
                        continue
                else:
                    m = re.match(r'^\@\@ -\S+ \+(\d+)', line)
                    if m:
                        self._lineno = int(m.group(1)) - 1
                        continue

                if re.match(r'^diff ', line):
                    # Line is start of a new file
                    self._file_end()
                    m = re.match(r'^diff --git "\\\\@old\\\\@\/.+" "\\\\@new\\\\@\/(.+)"$', line)
                    if m:
                        self._filename = m.group(1)
                        self._merge = False
                    else:
                        m = re.match(r'^diff --cc (.+)$', line)
                        if m:
                            self._filename = m.group(1)
                            self._merge = True
                        else:
                            print("Warning: cannot parse diff header '{0}'".format(line), file=sys.stderr)
                            continue
                    print_if_verbose("*** file " + self._filename, args)
                    self._conflict = ('conflict' in self._skip_keys)
                    self._crlf = ('crlf' in self._skip_keys)
                    self._check_ws = (not 'style' in self._skip_keys)

        # Ensure problems found in current file are handled
        self._file_end()


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def process_kwargs(defaults, kwargs):
    '''
    Check kwargs dictionary against an 'allowed' dictionary
    Each key in the allowed dictionary has an associated default value; if the
    key is not found in kwargs, the default value is used instead
    '''
    diff = set(kwargs.keys()) - set(defaults.keys())
    if diff:
        raise TypeError('Error: invalid arguments: %s' % list(diff))
    defaults.update(kwargs)
    return defaults


def parse_cmd_line():
    parser = ArgumentParser()
    return parser.parse_args()


def execute(cmd, args):
    '''
    Execute a shell command and capture the output
    '''
    if args.verbose:
        print('\n' + cmd)
    output = []
    if not args.dry_run:
        process = subprocess.Popen(cmd.split(),
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
        while (True):
            line = process.stdout.readline()
            if len(line) == 0:
                break
            output.append(line)
    return output


def print_if_verbose(line, args):
    if args.verbose:
        print(line, end=' ')


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_cmd_line()
checker = CommitChecker(args)

# If checker found any problems, exit with non-zero value, causing 'git commit'
# to abort
sys.exit(checker.retval())

