#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import os
import sys

__all__ = ['stdout', 'stderr', 'stdin']


#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

BLACK     = 0
BLUE      = 1
GREEN     = 2
CYAN      = 3
RED       = 4
MAGENTA   = 5
YELLOW    = 6
GREY      = 7
WHITE     = 8

INTENSITY = 100


#------------------------------------------------------------------------------
# Console
#------------------------------------------------------------------------------

class Stack(list):
    def push(self, item):
        self.append(item)

    def is_empty(self):
        return not self


class ConsoleColor(object):
    def __init__(self):
        self.stack = Stack()
        self.value = None

    def push(self, color):
        self.stack.push(color)
        self.value = color

    def pop(self):
        return self.stack.pop()


class OutputStreamBase(object):
    def __init__(self, stream):
        self.stream = stream
        self.fg = ConsoleColor()
        self.bg = ConsoleColor()

    def set_fg(self, color):
        self.fg.value = color

    def push_fg(self, color):
        self.fg.push(color)

    def pop_fg(self):
        return self.fg.pop()

    def set_bg(self, color):
        self.bg.value = color

    def push_bg(self, color):
        self.bg.push(color)

    def pop_bg(self):
        return self.bg.pop()

    def write(self, value):
        self._apply_colors(self.fg.value, self.bg.value)
        self.stream.write(value)
        self._apply_colors(WHITE, BLACK)

    def flush(self):
        self.stream.flush()


if os.name == 'nt':
    import ctypes, msvcrt

    class OutputStream(OutputStreamBase):

        # From http://stackoverflow.com/questions/384076/how-can-i-make-the-python-logging-output-to-be-colored

        # wincon.h
        FG_DICT = {
            BLACK     : 0x0000,
            BLUE      : 0x0001,
            GREEN     : 0x0002,
            CYAN      : 0x0003,
            RED       : 0x0004,
            MAGENTA   : 0x0005,
            YELLOW    : 0x0006,
            GREY      : 0x0007,
            INTENSITY : 0x0008, # foreground color is intensified.
            WHITE     : 0x0007, # BLUE | GREEN | RED
        }

        # wincon.h
        BG_DICT = {
            BLACK     : 0x0000,
            BLUE      : 0x0010,
            GREEN     : 0x0020,
            CYAN      : 0x0030,
            RED       : 0x0040,
            MAGENTA   : 0x0050,
            YELLOW    : 0x0060,
            GREY      : 0x0070,
            INTENSITY : 0x0080, # background color is intensified.
            WHITE     : 0x0070, # BLUE | GREEN | RED
        }

        # winbase.h
        STREAM_DICT = {
            sys.stdout : -11,
            sys.stderr : -12
        }

        def __init__(self, stream):
            OutputStreamBase.__init__(self, stream)

        def _apply_colors(self, fg, bg):
            mask = 0
            if fg:
                mask |= OutputStream.FG_DICT[fg]
            if bg:
                mask |= OutputStream.BG_DICT[bg]
            if mask != 0:
                handle = ctypes.windll.kernel32.GetStdHandle(OutputStream.STREAM_DICT[self.stream])
                ctypes.windll.kernel32.SetConsoleTextAttribute(handle, mask)


    class InputStream(object):
        def __init__(self):
            pass

        def getkey(self):
            while True:
                z = msvcrt.getch()
                if z == '\0' or z == '\xe0':    # functions keys, ignore
                    msvcrt.getch()
                else:
                    if z == '\r':
                        return '\n'
                    return z

    stdout = OutputStream(sys.stdout)
    stderr = OutputStream(sys.stderr)
    stdin = InputStream()

elif os.name == 'posix':
    import atexit, os, termios

    class OutputStream(OutputStreamBase):

        FG_DICT = {
            BLACK     : '',
            BLUE      : '\033[0;34m',
            GREEN     : '\033[1;32m',
            CYAN      : '\033[1;36m',
            RED       : '\033[0;31m',
            MAGENTA   : '\033[1;35m',
            YELLOW    : '\033[1;33m',
            GREY      : '',
            WHITE     : '\033[1;37m',
            INTENSITY : '',
        }

        BG_DICT = {
            BLACK     : '',
            BLUE      : '',
            GREEN     : '',
            CYAN      : '',
            RED       : '',
            MAGENTA   : '',
            YELLOW    : '',
            GREY      : '',
            WHITE     : '',
            INTENSITY : '',
        }

        def __init__(self, stream):
            OutputStreamBase.__init__(self, stream)

        def _apply_colors(self, fg, bg):
            if fg:
                self.stream.write(OutputStream.FG_DICT[fg])
            if bg:
                self.stream.write(OutputStream.BG_DICT[bg])


    class InputStream(object):
        def __init__(self):
            self.fd = sys.stdin.fileno()

        def _setup(self):
            self.old = termios.tcgetattr(self.fd)
            new = termios.tcgetattr(self.fd)
            new[3] = new[3] & ~termios.ICANON & ~termios.ECHO & ~termios.ISIG
            new[6][termios.VMIN] = 1
            new[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, new)

        def getkey(self):
            c = os.read(self.fd, 1)
            return c

        def _cleanup(self):
            termios.tcsetattr(self.fd, termios.TCSAFLUSH, self.old)

    stdout = OutputStream(sys.stdout)
    stderr = OutputStream(sys.stderr)
    stdin = InputStream()

    def _cleanup():
        stdin._cleanup()

    stdin._setup()

    # Terminal modes have to be restored on exit
    atexit.register(_cleanup)

else:
    raise NotImplementedError("Sorry no implementation for your platform (%s) available." % sys.platform)


