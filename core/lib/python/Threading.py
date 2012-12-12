#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import threading

__all__ = ['RepeatTimer']


#------------------------------------------------------------------------------
# RepeatTimer
# http://mail.python.org/pipermail/python-ideas/2011-January/009063.html
#------------------------------------------------------------------------------

class RepeatTimer(threading.Thread):
    def __init__(self, interval, callable, *args, **kwargs):
        threading.Thread.__init__(self)
        self.interval = interval
        self.callable = callable
        self.args = args
        self.kwargs = kwargs
        self.event = threading.Event()
        self.event.set()

    def run(self):
        while self.event.is_set():
            t = threading.Timer(self.interval, self.callable,
                                self.args, self.kwargs)
            t.start()
            t.join()

    def cancel(self):
        self.event.clear()

