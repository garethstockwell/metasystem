"""
This module provides logging functionality, primarily:

* Custom formatters for use with the standard logging module
* Decorators which can be used to instrument code
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import absolute_import

import logging
from logging import *

import sys

import metasystem.script


#------------------------------------------------------------------------------
# Formatters
#------------------------------------------------------------------------------

class FormatterBase(logging.Formatter):

    def __init__(self):

        super(FormatterBase, self).__init__()

        self.debug = False


class ConsoleFormatter(FormatterBase):

    FORMAT = { logging.DEBUG: '[DEBUG %(module)s %(lineno)d] %(msg)s',
               logging.WARN:  'Warning: %(msg)s',
               logging.ERROR: 'Error: %(msg)s',
               logging.INFO:  '%(msg)s' }

    DEBUG_FORMAT = { logging.DEBUG: '[D %(module)s %(lineno)d] %(msg)s',
                     logging.WARN:  '[W %(module)s %(lineno)d] Warning: %(msg)s',
                     logging.ERROR: '[E %(module)s %(lineno)d] Error: %(msg)s',
                     logging.INFO:  '[I %(module)s %(lineno)d] %(msg)s' }

    def __init__(self):

        super(ConsoleFormatter, self).__init__()


    def format(self, record):

        table = {True: self.DEBUG_FORMAT, False: self.FORMAT}.get(self.debug)
        self._fmt = table.get(record.levelno, self.FORMAT[logging.INFO])
        return logging.Formatter.format(self, record)


class FileFormatter(FormatterBase):

    FORMAT = { logging.DEBUG: '[D{0:s}] %(asctime)s %(msg)s',
               logging.WARN:  '[W{0:s}] %(asctime)s %(msg)s',
               logging.ERROR: '[E{0:s}] %(asctime)s %(msg)s',
               logging.INFO:  '[I{0:s}] %(asctime)s %(msg)s' }

    def __init__(self):

        super(FileFormatter, self).__init__()


    def format(self, record):

        self._fmt = self.FORMAT.get(record.levelno, self.FORMAT[logging.INFO])
        location = {True: '', False: ''}.get(self.debug)
        self._fmt = self._fmt.format(location)
        return logging.Formatter.format(self, record)


#------------------------------------------------------------------------------
# Filters
#------------------------------------------------------------------------------

class ErrorFilter(logging.Filter):

    def __init__(self, value):

        super(ErrorFilter, self).__init__()
        self.value = value


    def filter(self, rec):

        return (rec.levelno == logging.ERROR) == self.value


#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------

def _format_args(*args, **kwargs):
    """
    Helper function used by the logging decorators
    """

    all_args = []

    for item in args:
        all_args.append('{0:s}'.format(str(item)))

    for key, value in kwargs.items():
        all_args.append('{0:s}={1:s}'.format(key, str(value)))

    result = ', '.join(all_args)
    if len(result) > 150:
        return result[:146] + " ..."
    return result


#------------------------------------------------------------------------------
# LevelContext
#------------------------------------------------------------------------------

class LevelContext(object):
    '''
    Class for temporarily changing logging level:

    with logging.LevelContext(logging.DEBUG):
        # do stuff
    '''

    def __init__(self, level, logger=None):

        self._level = level
        self._old_level = None
        self._logger = logger or logging.getLogger()


    def __enter__(self):

        self._old_level = self._logger.getEffectiveLevel()
        self._logger.setLevel(self._level)


    def __exit__(self, type, value, traceback):

        self._logger.setLevel(self._old_level)


#------------------------------------------------------------------------------
# FileHandlerContext
#------------------------------------------------------------------------------

class FileHandlerContext(object):
    '''
    Class for temporarily redirecting logging to a file:

    with logging.FileHandlerContext(logging.DEBUG):
        # do stuff
    '''

    def __init__(self, filename, logger=None):

        self._filename = filename
        self._logger = logger or logging.getLogger()
        self._old_handlers = self._logger.handlers


    def __enter__(self):

        init(logger=self._logger)
        add_file_handler(self._filename, logger=self._logger)


    def __exit__(self, type, value, traceback):

        self._logger.handlers = self._old_handlers


#------------------------------------------------------------------------------
# Decorators
#------------------------------------------------------------------------------

def log_function(func):
    """
    Decorator which causes each invocation of a function to be logged.

    Use it like this:

    @log_function
    def my_function(foo, bar):
        ...
    """

    def _wrapper(*args, **kwargs):

        if metasystem.script.debug:
            sys.stderr.write('[D {1:s}] {2:s}\n'.format(
                             func.__name__,
                             _format_args(*args, **kwargs)))
        ret = func(self, *args, **kwargs)
        return ret

    return _wrapper


def log_method(func):
    """
    Decorator which causes each invocation of a method to be logged.

    Use it like this:

    @log_method
    def my_method(self, foo, bar):
        ...
    """

    def _wrapper(self, *args, **kwargs):

        if metasystem.script.debug:
            sys.stderr.write('[D {0:s} {1:d}] {2:s}[0x{3:08x}].{4:s} {5:s}\n'.format(
                             self.__module__,
                             func.func_code.co_firstlineno,
                             self.__class__.__name__,
                             id(self),
                             func.__name__,
                             _format_args(*args, **kwargs)))
        ret = func(self, *args, **kwargs)
        return ret

    return _wrapper


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def init(logger=None):

    logger = logger or logging.getLogger()

    # Slightly dodgy - we are assigning to a member variable
    # since there is no logging.Logger method for clearing the list
    # of handlers
    logger.handlers = []


def add_console_handler(logger=None):

    logger = logger or logging.getLogger()

    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setFormatter(ConsoleFormatter())
    stdout_handler.addFilter(ErrorFilter(False))
    logger.addHandler(stdout_handler)

    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setFormatter(ConsoleFormatter())
    stderr_handler.addFilter(ErrorFilter(True))
    logger.addHandler(stderr_handler)



def add_file_handler(filename, logger=None):

    logger = logger or logging.getLogger()
    handler = logging.FileHandler(filename)
    handler.setFormatter(FileFormatter())
    logger.addHandler(handler)


def init_level(quiet=False, debug=False, logger=None):

    logger = logger or logging.getLogger()
    if not quiet:
        logger.setLevel(logging.INFO)
    if debug:
        logger.setLevel(logging.DEBUG)
        for handler in logger.handlers:
            formatter = handler.formatter
            if isinstance(formatter, FormatterBase):
                formatter.debug = True

