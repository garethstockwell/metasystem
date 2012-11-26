#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import logging
import threading

__all__ = []


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def log_debug(msg):
    logging.debug(('[%d] Serterm.' %
                    (threading.current_thread().ident)) + msg)


#------------------------------------------------------------------------------
# Filters
#------------------------------------------------------------------------------

class FilterOutput(object):
    def __init__(self, msg):
        n = len(msg)
        self.fg = n * [None]
        self.bg = n * [None]
        self.msg = msg


class FilterChain(object):
    def __init__(self):
        self.filters = []

    def filter(self, msg):
        ret = FilterOutput(msg)
        for f in self.filters:
            ret = f.filter(ret)
        return ret


class Filter(object):
    POP = -1

    def __init__(self):
        pass

    def filter(self, msg):
        return msg


class TestFilter(Filter):
    def __init__(self):
        log_debug("TestFilter.__init__")
        Filter.__init__(self)

    def filter(self, msg):
        log_debug("TestFilter.filter msg '%s" % (msg.msg))
        return msg

