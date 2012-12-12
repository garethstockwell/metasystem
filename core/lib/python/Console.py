#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import copy
import os
import sys
from types import BuiltinMethodType, MethodType

from Wrapper import Wrapper

__all__ = ['Color', 'Intensity']


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

STDERR_HOOK = 1


#------------------------------------------------------------------------------
# Enums
#------------------------------------------------------------------------------

class Color:
    BLACK     = 0
    RED       = 1
    GREEN     = 2
    YELLOW    = 3
    BLUE      = 4
    MAGENTA   = 5
    CYAN      = 6
    WHITE     = 7

class Intensity:
    DIM       = 1
    NORMAL    = 2
    BRIGHT    = 3


#------------------------------------------------------------------------------
# RenderState
#------------------------------------------------------------------------------

class RenderState(object):
    def __init__(self):
        self.fg = Color.WHITE
        self.bg = Color.BLACK
        self.intensity = Intensity.NORMAL

    def __eq__(self, other):
        return self.fg == other.fg and \
               self.bg == other.bg and \
               self.intensity == other.intensity

    def __ne__(self, other):
        return self.fg != other.fg or \
               self.bg != other.bg or \
               self.intensity != other.intensity

    def __repr__(self):
        return 'fg %d bg %d intensity %d' % (self.fg, self.bg, self.intensity)


#------------------------------------------------------------------------------
# ANSI
#------------------------------------------------------------------------------

class Ansi(object):
    FG = {
        Color.BLACK       : 30,
        Color.RED         : 31,
        Color.GREEN       : 32,
        Color.YELLOW      : 33,
        Color.BLUE        : 34,
        Color.MAGENTA     : 35,
        Color.CYAN        : 36,
        Color.WHITE       : 37,
    }

    FG_REV = dict((v,k) for k,v in FG.items())

    BG = {
        Color.BLACK       : 40,
        Color.RED         : 41,
        Color.GREEN       : 42,
        Color.YELLOW      : 43,
        Color.BLUE        : 44,
        Color.MAGENTA     : 45,
        Color.CYAN        : 46,
        Color.WHITE       : 47,
    }

    BG_REV = dict((v,k) for k,v in BG.items())

    INTENSITY = {
        Intensity.DIM     : 2,
        Intensity.NORMAL  : 22,
        Intensity.BRIGHT  : 1,
    }

    INTENSITY_REV = dict((v,k) for k,v in INTENSITY.items())

    @classmethod
    def renderstate_to_ansi(self, rs):
        esc = '\033['
        if state.fg():
            esc += '%d;' % (ANSI.FG[state.fg()])
        if state.bg():
            esc += '%d;' % (ANSI.BG[state.bg()])
        if state.intensity():
            esc += '%d;' % (ANSI.INTENSITY[state.intensity()])
        esc += 'm'

    @classmethod
    def ansi_to_renderstate(self, esc):
        esc = esc.lstrip('\033[')
        esc = esc.rstrip('m')
        tokens = esc.split(';')
        rs = RenderState()
        for t in tokens:
            rs.fg = Ansi.FG_REV.get(int(t), rs.fg)
            rs.bg = Ansi.BG_REV.get(int(t), rs.bg)
            rs.intensity = Ansi.INTENSITY_REV.get(int(t), rs.intensity)
        return rs

#------------------------------------------------------------------------------
# Console
#------------------------------------------------------------------------------

class Stack(list):
    def push(self, item):
        self.append(item)

    def pop(self):
        item = list.pop(self)
        return item

    def is_empty(self):
        return not self


class OutputStreamState(object):
    def __init__(self, default=RenderState()):
        self.default = copy.copy(default)
        self.current = copy.copy(default)
        self.dirty = False
        self.stack = Stack()

    def reset(self):
        self.set(self.default)

    def save_default(self):
        self.default = copy.copy(self.current)

    def fg(self):
        return self.current.fg

    def set_fg(self, color):
        if color != self.current.fg:
            self.current.fg = color
            self.dirty = True

    def bg(self):
        return self.current.bg

    def set_bg(self, color):
        if color != self.current.bg:
            self.current.bg = color
            self.dirty = True

    def intensity(self):
        return self.current.intensity

    def set_intensity(self, value):
        if value != self.current.intensity:
            self.current.intensity = value
            self.dirty = True

    def set(self, state):
        if self.current != state:
            self.current = copy.copy(state)
            self.dirty = True

    def push(self):
        self.stack.push(copy.copy(self.current))

    def pop(self):
        if not self.stack.is_empty():
            state = copy.copy(self.stack.pop())
            self.set(state)


class OutputStreamBase(Wrapper):
    def __init__(self, stream):
        Wrapper.__init__(self, stream)
        self.stream = stream
        self.state = OutputStreamState()

    def _wrap_pre(self, func, args, kwargs):
        if type(func) == BuiltinMethodType and func.__name__ == 'write':
            if self.state.dirty:
                self._apply_state()
                self.state.dirty = False


if os.name == 'nt':
    import ctypes, msvcrt

    class OutputStream(OutputStreamBase):

        # From http://stackoverflow.com/questions/384076/how-can-i-make-the-python-logging-output-to-be-colored

        # wincon.h
        FG = {
            Color.BLACK     : 0x0000,
            Color.BLUE      : 0x0001,
            Color.GREEN     : 0x0002,
            Color.CYAN      : 0x0003,
            Color.RED       : 0x0004,
            Color.MAGENTA   : 0x0005,
            Color.YELLOW    : 0x0006,
            Color.WHITE     : 0x0007,
        }

        FG_BRIGHT = 0x0008

        # wincon.h
        BG = {
            Color.BLACK     : 0x0000,
            Color.BLUE      : 0x0010,
            Color.GREEN     : 0x0020,
            Color.CYAN      : 0x0030,
            Color.RED       : 0x0040,
            Color.MAGENTA   : 0x0050,
            Color.YELLOW    : 0x0060,
            Color.WHITE     : 0x0070,
        }

        BG_BRIGHT = 0x0080

        # winbase.h
        STREAM = {
            sys.__stdout__  : -11,
            sys.__stderr__  : -12
        }

        def __init__(self, stream):
            OutputStreamBase.__init__(self, stream)

        def _apply_state(self):
            mask = 0
            if self.state.fg():
                mask |= OutputStream.FG[self.state.fg()]
            if self.state.bg():
                mask |= OutputStream.BG[self.state.bg()]
            if self.state.intensity() == Intensity.BRIGHT:
                mask |= OutputStream.FG_BRIGHT
            if mask != 0:
                handle = ctypes.windll.kernel32.GetStdHandle(OutputStream.STREAM[self.stream])
                ctypes.windll.kernel32.SetConsoleTextAttribute(handle, mask)
                if self == sys.stdout and STDERR_HOOK:
                    sys.stderr.state.dirty = True
                if self == sys.stderr:
                    sys.stdout.state.dirty = True


    class InputStream(Wrapper):
        def __init__(self):
            Wrapper.__init__(self, sys.__stdin__)

        def get_key(self):
            while True:
                z = msvcrt.getch()
                if z == '\0' or z == '\xe0':    # functions keys, ignore
                    msvcrt.getch()
                else:
                    if z == '\r':
                        return '\n'
                    return z

    sys.stdout = OutputStream(sys.__stdout__)
    if STDERR_HOOK:
        sys.stderr = OutputStream(sys.__stderr__)
    sys.stdin = InputStream()

elif os.name == 'posix':
    import atexit, os, termios

    class OutputStream(OutputStreamBase):
        def __init__(self, stream):
            OutputStreamBase.__init__(self, stream)

        def _apply_state(self):
            self.stream.write(Ansi.renderstate_to_ansi(self.state.current))


    class InputStream(Wrapper):
        def __init__(self):
            fd = sys.stdin.fileno()
            Wrapper.__init__(self, sys.__stdin__)
            self.fd = fd

        def _setup(self):
            self.old = termios.tcgetattr(self.fd)
            new = termios.tcgetattr(self.fd)
            new[3] = new[3] & ~termios.ICANON & ~termios.ECHO & ~termios.ISIG
            new[6][termios.VMIN] = 1
            new[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, new)

        def get_key(self):
            c = os.read(self.fd, 1)
            return c

        def _cleanup(self):
            termios.tcsetattr(self.fd, termios.TCSAFLUSH, self.old)

    sys.stdout = OutputStream(sys.__stdout__)
    if STDERR_HOOK:
        sys.stderr = OutputStream(sys.__stderr__)
    sys.stdin = InputStream()

    def _cleanup():
        stdin._cleanup()

    stdin._setup()

    # Terminal modes have to be restored on exit
    atexit.register(_cleanup)

else:
    raise NotImplementedError("Sorry no implementation for your platform (%s) available." % sys.platform)

