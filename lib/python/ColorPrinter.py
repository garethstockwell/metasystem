#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import sys
import platform


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

class Verbosity:
    Silent = 0
    Normal = 1
    Loud = 2

YellowThreshold = 60 * 60 * 24 * 7
RedThreshold = YellowThreshold * 2

EnableColor = True


#------------------------------------------------------------------------------
# Coloring
# This should really be in a module...
#------------------------------------------------------------------------------

class TermColor:
    FOREGROUND_BLACK     = 0
    FOREGROUND_BLUE      = 1
    FOREGROUND_GREEN     = 2
    FOREGROUND_CYAN      = 3
    FOREGROUND_RED       = 4
    FOREGROUND_MAGENTA   = 5
    FOREGROUND_YELLOW    = 6
    FOREGROUND_GREY      = 7
    FOREGROUND_WHITE     = 8

    BACKGROUND_BLACK     = 100
    BACKGROUND_BLUE      = 101
    BACKGROUND_GREEN     = 102
    BACKGROUND_CYAN      = 103
    BACKGROUND_RED       = 104
    BACKGROUND_MAGENTA   = 105
    BACKGROUND_YELLOW    = 106
    BACKGROUND_GREY      = 107
    BACKGROUND_WHITE     = 108


class StdStream:
    STDOUT = 1
    STDERR = 2

StreamDict = {
    StdStream.STDOUT : sys.stdout,
    StdStream.STDERR : sys.stderr
}


# From http://stackoverflow.com/questions/384076/how-can-i-make-the-python-logging-output-to-be-colored
class Win32TermColor:
    # winbase.h
    STD_OUTPUT_HANDLE = -11
    STD_ERROR_HANDLE  = -12

    # wincon.h
    FOREGROUND_BLACK     = 0x0000
    FOREGROUND_BLUE      = 0x0001
    FOREGROUND_GREEN     = 0x0002
    FOREGROUND_CYAN      = 0x0003
    FOREGROUND_RED       = 0x0004
    FOREGROUND_MAGENTA   = 0x0005
    FOREGROUND_YELLOW    = 0x0006
    FOREGROUND_GREY      = 0x0007
    FOREGROUND_INTENSITY = 0x0008 # foreground color is intensified.

    FOREGROUND_WHITE     = FOREGROUND_BLUE|FOREGROUND_GREEN |FOREGROUND_RED

    BACKGROUND_BLACK     = 0x0000
    BACKGROUND_BLUE      = 0x0010
    BACKGROUND_GREEN     = 0x0020
    BACKGROUND_CYAN      = 0x0030
    BACKGROUND_RED       = 0x0040
    BACKGROUND_MAGENTA   = 0x0050
    BACKGROUND_YELLOW    = 0x0060
    BACKGROUND_GREY      = 0x0070
    BACKGROUND_INTENSITY = 0x0080 # background color is intensified.

    BACKGROUND_WHITE     = BACKGROUND_BLUE|BACKGROUND_GREEN |BACKGROUND_RED

    StreamDict = {
        StdStream.STDOUT : STD_OUTPUT_HANDLE,
        StdStream.STDERR : STD_ERROR_HANDLE
    }

    ColorDict = {
        TermColor.FOREGROUND_BLACK      : FOREGROUND_BLACK,
        TermColor.FOREGROUND_BLUE       : FOREGROUND_BLUE,
        TermColor.FOREGROUND_GREEN      : FOREGROUND_GREEN,
        TermColor.FOREGROUND_CYAN       : FOREGROUND_CYAN,
        TermColor.FOREGROUND_RED        : FOREGROUND_RED,
        TermColor.FOREGROUND_MAGENTA    : FOREGROUND_MAGENTA,
        TermColor.FOREGROUND_YELLOW     : FOREGROUND_YELLOW,
        TermColor.FOREGROUND_GREY       : FOREGROUND_GREY,
        TermColor.FOREGROUND_WHITE      : FOREGROUND_WHITE,

        TermColor.BACKGROUND_BLACK      : BACKGROUND_BLACK,
        TermColor.BACKGROUND_BLUE       : BACKGROUND_BLUE,
        TermColor.BACKGROUND_GREEN      : BACKGROUND_GREEN,
        TermColor.BACKGROUND_CYAN       : BACKGROUND_CYAN,
        TermColor.BACKGROUND_RED        : BACKGROUND_RED,
        TermColor.BACKGROUND_MAGENTA    : BACKGROUND_MAGENTA,
        TermColor.BACKGROUND_YELLOW     : BACKGROUND_YELLOW,
        TermColor.BACKGROUND_GREY       : BACKGROUND_GREY,
        TermColor.BACKGROUND_WHITE      : BACKGROUND_WHITE
    }

    def _win32handle(self, stream = StdStream.STDOUT):
        import ctypes
        handle = self.StreamDict[stream]
        return ctypes.windll.kernel32.GetStdHandle(handle)

    def _win32color(self, color):
        return self.ColorDict[color]

    def setColor(self, color, stream = StdStream.STDOUT):
        import ctypes
        win32Color = self._win32color(color)
        win32Handle = self._win32handle(stream)
        ctypes.windll.kernel32.SetConsoleTextAttribute(win32Handle, win32Color)


class AnsiTermColor:
    FOREGROUND_BLACK     = ''            # ??
    FOREGROUND_BLUE      = '\033[0;34m'
    FOREGROUND_GREEN     = '\033[1;32m'
    FOREGROUND_CYAN      = '\033[1;36m'
    FOREGROUND_RED       = '\033[0;31m'
    FOREGROUND_MAGENTA   = '\033[1;35m' # Pink?
    FOREGROUND_YELLOW    = '\033[1;33m'
    FOREGROUND_GREY      = ''            # ??
    FOREGROUND_WHITE     = '\033[1;37m'

    BACKGROUND_BLACK     = ''            # ??
    BACKGROUND_BLUE      = ''            # ??
    BACKGROUND_GREEN     = ''            # ??
    BACKGROUND_CYAN      = ''            # ??
    BACKGROUND_RED       = ''            # ??
    BACKGROUND_MAGENTA   = ''            # ??
    BACKGROUND_YELLOW    = ''            # ??
    BACKGROUND_GREY      = ''            # ??
    BACKGROUND_INTENSITY = ''            # ??
    BACKGROUND_WHITE     = ''

    ColorDict = {
        TermColor.FOREGROUND_BLACK      : FOREGROUND_BLACK,
        TermColor.FOREGROUND_BLUE       : FOREGROUND_BLUE,
        TermColor.FOREGROUND_GREEN      : FOREGROUND_GREEN,
        TermColor.FOREGROUND_CYAN       : FOREGROUND_CYAN,
        TermColor.FOREGROUND_RED        : FOREGROUND_RED,
        TermColor.FOREGROUND_MAGENTA    : FOREGROUND_MAGENTA,
        TermColor.FOREGROUND_YELLOW     : FOREGROUND_YELLOW,
        TermColor.FOREGROUND_GREY       : FOREGROUND_GREY,
        TermColor.FOREGROUND_WHITE      : FOREGROUND_WHITE,

        TermColor.BACKGROUND_BLACK      : BACKGROUND_BLACK,
        TermColor.BACKGROUND_BLUE       : BACKGROUND_BLUE,
        TermColor.BACKGROUND_GREEN      : BACKGROUND_GREEN,
        TermColor.BACKGROUND_CYAN       : BACKGROUND_CYAN,
        TermColor.BACKGROUND_RED        : BACKGROUND_RED,
        TermColor.BACKGROUND_MAGENTA    : BACKGROUND_MAGENTA,
        TermColor.BACKGROUND_YELLOW     : BACKGROUND_YELLOW,
        TermColor.BACKGROUND_GREY       : BACKGROUND_GREY,
        TermColor.BACKGROUND_WHITE      : BACKGROUND_WHITE
    }

    def setColor(self, color, stream = StdStream.STDOUT):
        output = StreamDict[stream]
        output.write(self.ColorDict[color])


class ColorPrinter:
    def __init__(self, stream = StdStream.STDOUT, color = None):
        self.stream = stream
        self.color = color
        if platform.system() == 'Windows':
            self.color_ctrl = Win32TermColor()
        else:
            self.color_ctrl = AnsiTermColor()

    def set_color(self, color):
        self.color = color

    def write(self, text, color=None):
        if color:
            self.color = color
        if self.color:
            self.color_ctrl.setColor(self.color, self.stream)
        output = StreamDict[self.stream]
        output.write(text)

    def flush(self):
        output = StreamDict[self.stream]
        output.flush()

    def printToConsole(self, text, color=None):
        self.write(text, color=color)

    def __del__(self):
        self.color_ctrl.setColor(TermColor.BACKGROUND_BLACK)
        self.color_ctrl.setColor(TermColor.FOREGROUND_WHITE)



