#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import os


#------------------------------------------------------------------------------
# Colors
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


# From http://stackoverflow.com/questions/384076/how-can-i-make-the-python-logging-output-to-be-colored
class Win32TermColor:
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


class AnsiTermColor:
    FOREGROUND_BLACK     = ''            # ??
    FOREGROUND_BLUE      = '\033[0;34m'
    FOREGROUND_GREEN     = '\033[1;32m'
    FOREGROUND_CYAN      = '\033[1;36m'
    FOREGROUND_RED       = '\033[0;31m'
    FOREGROUND_MAGENTA   = '\033[1;35m'  # Pink?
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


#------------------------------------------------------------------------------
# Streams
#------------------------------------------------------------------------------

class TermStream:
    STDOUT = 1
    STDERR = 2


#------------------------------------------------------------------------------
# Console
#------------------------------------------------------------------------------

if os.name == 'nt':
    import msvcrt
    class Console(object):
        def __init__(self):
            pass

        def setup(self):
            pass    # Do nothing for 'nt'

        def cleanup(self):
            pass    # Do nothing for 'nt'

        def getkey(self):
            while True:
                z = msvcrt.getch()
                if z == '\0' or z == '\xe0':    # functions keys, ignore
                    msvcrt.getch()
                else:
                    if z == '\r':
                        return '\n'
                    return z

    console = Console()

elif os.name == 'posix':
    import termios, sys, os
    class Console(object):
        def __init__(self):
            self.fd = sys.stdin.fileno()

        def setup(self):
            self.old = termios.tcgetattr(self.fd)
            new = termios.tcgetattr(self.fd)
            new[3] = new[3] & ~termios.ICANON & ~termios.ECHO & ~termios.ISIG
            new[6][termios.VMIN] = 1
            new[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, new)

        def getkey(self):
            c = os.read(self.fd, 1)
            return c

        def cleanup(self):
            termios.tcsetattr(self.fd, termios.TCSAFLUSH, self.old)

    console = Console()

    def console_cleanup():
        sys.stderr.write("console_cleanup\n")
        console.cleanup()

    console.setup()
    sys.exitfunc = cleanup_console      # terminal modes have to be restored on exit...

else:
    raise NotImplementedError("Sorry no implementation for your platform (%s) available." % sys.platform)


