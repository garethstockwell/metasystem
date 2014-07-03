"""
This module provides various utilities which don't neatly fit into any of the
other modules.
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import absolute_import

import logging
import os
import sys

import metasystem.script


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

_BOOL_TO_STRING = { True: 'yes', False: 'no' }
_STRING_TO_BOOL = { 'yes': True, 'no': False }


#------------------------------------------------------------------------------
# KeyValueFormatter
#------------------------------------------------------------------------------

class KeyValueFormatter(object):
    """
    Pretty-printer used to format key-value pairs.

    Generates output like this:

    foo .................... some value here
    blah_di_blah ........... another value here, nicely aligned
    """

    def __init__(self, key_width=20):

        self.key_width = key_width

    def format(self, key, value):

        fmt = '{0:s} ' + '.' * (self.key_width - len(key)) + ' {1:s}'
        return fmt.format(key, value)


#------------------------------------------------------------------------------
# WaitLoop
#------------------------------------------------------------------------------

class WaitLoop(object):

    def __init__(self, stream=sys.stderr,
                       desc=None):

        self.stream = stream
        self.desc = desc


    def start(self, interval=0.5,
                    timeout=None):

        import datetime
        import time

        start_time = datetime.datetime.now()

        msg = None

        while True:
            delta = datetime.datetime.now() - start_time
            if timeout is not None and delta.seconds >= timeout:
                if self.stream:
                    self.stream.write('\n')
                metasystem.script.error('Timed out')

            ret = self.run()
            if ret is not None:
                if msg and self.stream:
                    self.stream.write('\n')
                return ret

            delta = datetime.datetime.now() - start_time

            if msg and self.stream:
                self.stream.write('\b' * len(msg))

            if self.stream:
                msg = 'Waiting'
                if self.desc:
                    msg += ' for {0:s}'.format(self.desc)
                if timeout is None:
                    msg += ' ... ({0:d} s)'.format(delta.seconds)
                else:
                    msg += ' ... ({0:d} / {1:d} s)'.format(delta.seconds, self.args.wait_time)
                self.stream.write(msg)

            if timeout is not None and delta.seconds >= timeout:
                if self.stream:
                    self.stream.write('\n')
                metasystem.script.error('Timed out')
            else:
                time.sleep(interval)


    def run(self):
        """
        Must be overridden by derived class
        Returns None if event has not completed
        """
        return None


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def unlink_silent(filename):

    try:
        if not metasystem.script.dry_run:
            os.remove(filename)
    except OSError:
        pass


def mkdir(path, allow_exists=False):

    if os.path.exists(path):
        if allow_exists:
            return
        else:
            err = metasystem.DirectoryAlreadyExistsError(path)
            if metasystem.script.dry_run:
                logging.warning(err.msg)
            else:
                raise err

    if not metasystem.script.dry_run:
        logging.info('Creating directory ' + path)
        os.makedirs(path)


def username():

    import getpass
    return getpass.getuser()


def assert_platform(name):

    import platform
    assert platform.system() == name


def assert_linux():

    assert_platform('Linux')


def split_into_lines(input, width=80):
    # Based on http://stackoverflow.com/questions/367155/splitting-a-string-into-words-and-punctuation

    import re
    result = []

    punc_single = [';', ',']
    punc_double = ['.', '!', '?']

    regex = r"[\w'-]+|["
    regex += ''.join(punc_single)
    regex += ''.join(punc_double)
    regex += r"]"

    punctuation = ['.', ',', '!', '?', ';']
    words = re.findall(r"[\w'-=]+|[" + ''.join(punctuation) + r"]", input)

    line = ''
    space = ' '
    for word in words:
        if len(line) == 0 or word in (punc_single + punc_double):
            space = ''

        if len(line) + len(space) + len(word) > width:
            result.append(line)
            line = word
        else:
            line += space + word

        if word in punc_double:
            space = '  '
        else:
            space = ' '

    if len(line) > 0:
        result.append(line)

    return result


def bool_to_str(value):

    return _BOOL_TO_STRING.get(value)


def str_to_bool(value):

    return _STRING_TO_BOOL.get(value)


def enum(*sequential, **named):
    '''
    Define an enum type

    Example:
    >>> Numbers = enum(ONE=1, TWO=2, THREE='three')
    >>> Numbers.ONE
    1
    >>> Numbers.TWO
    2
    >>> Numbers.THREE
    'three'

    http://stackoverflow.com/questions/36932/how-can-i-represent-an-enum-in-python
    '''
    enums = dict(zip(sequential, range(len(sequential))), **named)
    reverse = dict((value, key) for key, value in enums.iteritems())
    enums['reverse_mapping'] = reverse
    return type('Enum', (), enums)


def lower_first(s):

    return s[:1].lower() + s[1:] if s else ''


def arch():

    assert_linux()
    import subprocess
    cmd = subprocess.Popen(['uname', '-m'], stdout=subprocess.PIPE)
    result = cmd.communicate()[0].strip()
    if result.startswith('arm'):
        result = 'arm'
    return result


def debian_arch():

    assert_linux()
    import subprocess
    cmd = subprocess.Popen(['dpkg-architecture', '-qDEB_HOST_ARCH'], stdout=subprocess.PIPE)
    return cmd.communicate()[0].strip()


def print_callstack():

    import traceback
    for line in traceback.format_stack():
        logging.debug(line.strip())


def split_and_merge(input):
    """
    Takes an input like this:
        [ 'foo', 'bar,yah' ]
    and returns this:
        [ 'foo', 'bar', 'yah' ]
    """

    import itertools
    if input:
        return [ x for x in itertools.chain.from_iterable([ y.split(',') for y in input ]) ]
    else:
        return input


def get_input(prompt, valid=None, tries=3):

    if valid is None:
        tries = 1
    else:
        valid = [ str(x) for x in valid ]

    while tries > 0:
        value = raw_input(prompt + ' ')
        if valid is None or value in valid:
            return value
        tries -= 1

    raise metasystem.InputError('Invalid value')

