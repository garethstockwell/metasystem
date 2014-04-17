"""
Exit handlers
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import absolute_import

import atexit
import logging


#------------------------------------------------------------------------------
# ExitHandler
#------------------------------------------------------------------------------

_exit_handler_invoked = False

class ExitHandler(object):
    """
    This class is used to ensure that certain cleanup actions are taken
    when the program exits, even if this termination is premature or
    unexpected.
    """

    def __init__(self, func):

        logging.debug('ExitHandler.__init__ 0x{0:08x} func {1:s}'.format(
                      id(self), func.__name__))
        self.objects = []
        self.func = func
        atexit.register(ExitHandler.execute, self)


    def __del__(self):

        logging.debug('ExitHandler.__del__ 0x{0:08x}'.format(id(self)))


    def add(self, obj):

        logging.debug('ExitHandler 0x{0:08x} add {1:s}'.format(
                      id(self), object.__repr__(obj)))
        if not obj in self.objects:
            self.objects.append(obj)


    def remove(self, obj):

        logging.debug('ExitHandler 0x{0:08x} remove {1:s}'.format(
                      id(self), object.__repr__(obj)))
        if obj in self.objects:
            self.objects.remove(obj)


    def execute(self):

        global _exit_handler_invoked
        if not _exit_handler_invoked:
            logging.debug('Cleanup')
        _exit_handler_invoked = True

        logging.debug('ExitHandler 0x{0:08x} execute enter'.format(id(self)))
        self.objects.reverse()
        for obj in self.objects:
            logging.debug('ExitHandler 0x{0:08x} execute {1:s} enter'.format(
                          id(self), object.__repr__(obj)))
            self.func(obj)
            logging.debug('ExitHandler 0x{0:08x} execute {1:s} exit'.format(
                          id(self), object.__repr__(obj)))
        self.objects = []
        logging.debug('ExitHandler 0x{0:08x} execute exit'.format(id(self)))

