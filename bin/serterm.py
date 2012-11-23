#!/usr/bin/env python

# serterm

# Simple serial terminal
# Based on miniterm example, part of PySerial distribution

# TODO
# * Implement VT100 display attributes (http://www.termsys.demon.co.uk/vtansi.htm)
# * Refactor / clean up ColorPrinter library
#   - Move Console code from this file into library
#   - Tidy up color / display attribute handling
# * Add events API
#   - Listen on local socket
#   - Install / remove event handler which will respond to rx data


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import logging
import os
import serial
import sys
import threading

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
from ColorPrinter import *


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80

EXIT_CHARACTER = '\x1d'   # GS/CTRL+]


#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

global console


#------------------------------------------------------------------------------
# ArgumentParser
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    DEFAULT_RATE = 115200

    def __init__(self):
        description = 'Serial terminal'
        epilog = '''
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Positional arguments
        self.add_argument('port',
                          metavar='PORT',
                          help='Port')
        self.add_argument('rate',
                          metavar='RATE',
                          help='Baud rate (default {0})'.format(self.DEFAULT_RATE),
                          nargs='?',
                          default=self.DEFAULT_RATE)

        # Options
        self.add_argument('--debug',
                          dest='debug', default=False,
                          action='store_true',
                          help='show debugging output')
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-q', '--quiet',
                          dest='quiet', default=False,
                          action='store_true',
                          help='be quiet')
        self.add_argument('-v', '--verbose',
                          dest='verbose', default=False,
                          action='store_true',
                          help='produce verbose output')
        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

        self.add_argument('-p', '--parity',
                          dest='parity',
                          action='store',
                          default='N',
                          help="parity [N, E, O, S, M] (default N)")
        self.add_argument('--xonxoff',
                          dest='xonxoff',
                          action='store_true',
                          default=False,
                          help="enable software flow control (default off)")
        self.add_argument('--rtscts',
                          dest='rtscts',
                          action='store_true',
                          default=False,
                          help="enable RTS/CTS flow control (default off)")
        self.add_argument('--echo',
                          dest='echo',
                          action='store_true',
                          default=False,
                          help="enable echo (default off)")

        self.add_argument('--cr',
                          dest='cr',
                          action='store_true',
                          default=False,
                          help="do not sent CR+LF, send CR only")
        self.add_argument('--lf',
                          dest='lf',
                          action='store_true',
                          default=False,
                          help="do not send CR+LF, send LF only")


#------------------------------------------------------------------------------
# Miniterm
#------------------------------------------------------------------------------

CONVERT_CRLF = 2
CONVERT_CR   = 1
CONVERT_LF   = 0
NEWLINE_CONVERISON_MAP = ('\n', '\r', '\r\n')
LF_MODES = ('LF', 'CR', 'CR/LF')

REPR_MODES = ('raw', 'some control', 'all control', 'hex')

if sys.version_info >= (3, 0):
    def character(b):
        return b.decode('latin1')
else:
    def character(b):
        return b

class Miniterm(object):
    def __init__(self, port, baudrate, parity, rtscts, xonxoff, echo=False, convert_outgoing=CONVERT_CRLF, repr_mode=0):
        try:
            self.serial = serial.serial_for_url(port, baudrate, parity=parity, rtscts=rtscts, xonxoff=xonxoff, timeout=1)
        except AttributeError:
            # happens when the installed pyserial is older than 2.5. use the
            # Serial class directly then.
            self.serial = serial.Serial(port, baudrate, parity=parity, rtscts=rtscts, xonxoff=xonxoff, timeout=1)
        self.echo = echo
        self.repr_mode = repr_mode
        self.convert_outgoing = convert_outgoing
        self.newline = NEWLINE_CONVERISON_MAP[self.convert_outgoing]
        self.dtr_state = True
        self.rts_state = True
        self.break_state = False

        self.rx_console = ColorPrinter(color = TermColor.FOREGROUND_GREEN)
        self.echo_console = ColorPrinter(color = TermColor.FOREGROUND_YELLOW)

    def _start_reader(self):
        self._reader_alive = True
        # start serial->console thread
        self.receiver_thread = threading.Thread(target=self.reader)
        self.receiver_thread.setDaemon(True)
        self.receiver_thread.start()

    def _stop_reader(self):
        self._reader_alive = False
        self.receiver_thread.join()

    def start(self):
        self.alive = True
        self._start_reader()
        # enter console->serial loop
        self.transmitter_thread = threading.Thread(target=self.writer)
        self.transmitter_thread.setDaemon(True)
        self.transmitter_thread.start()

    def stop(self):
        self.alive = False

    def join(self, transmit_only=False):
        self.transmitter_thread.join()
        if not transmit_only:
            self.receiver_thread.join()

    def dump_port_settings(self):
        sys.stderr.write("\n--- Settings: %s  %s,%s,%s,%s\n" % (
                self.serial.portstr,
                self.serial.baudrate,
                self.serial.bytesize,
                self.serial.parity,
                self.serial.stopbits))
        sys.stderr.write('--- RTS: %-8s  DTR: %-8s  BREAK: %-8s\n' % (
                (self.rts_state and 'active' or 'inactive'),
                (self.dtr_state and 'active' or 'inactive'),
                (self.break_state and 'active' or 'inactive')))
        try:
            sys.stderr.write('--- CTS: %-8s  DSR: %-8s  RI: %-8s  CD: %-8s\n' % (
                    (self.serial.getCTS() and 'active' or 'inactive'),
                    (self.serial.getDSR() and 'active' or 'inactive'),
                    (self.serial.getRI() and 'active' or 'inactive'),
                    (self.serial.getCD() and 'active' or 'inactive')))
        except serial.SerialException:
            # on RFC 2217 ports it can happen to no modem state notification was
            # yet received. ignore this error.
            pass
        sys.stderr.write('--- software flow control: %s\n' % (self.serial.xonxoff and 'active' or 'inactive'))
        sys.stderr.write('--- hardware flow control: %s\n' % (self.serial.rtscts and 'active' or 'inactive'))
        sys.stderr.write('--- data escaping: %s  linefeed: %s\n' % (
                REPR_MODES[self.repr_mode],
                LF_MODES[self.convert_outgoing]))

    def reader(self):
        try:
            while self.alive and self._reader_alive:
                data = character(self.serial.read(1))

                if self.repr_mode == 0:
                    # direct output, just have to care about newline setting
                    if data == '\r' and self.convert_outgoing == CONVERT_CR:
                        self.rx_console.write('\n')
                    else:
                        self.rx_console.write(data)
                elif self.repr_mode == 1:
                    # escape non-printable, let pass newlines
                    if self.convert_outgoing == CONVERT_CRLF and data in '\r\n':
                        if data == '\n':
                            self.rx_console.write('\n')
                        elif data == '\r':
                            pass
                    elif data == '\n' and self.convert_outgoing == CONVERT_LF:
                        self.rx_console.write('\n')
                    elif data == '\r' and self.convert_outgoing == CONVERT_CR:
                        self.rx_console.write('\n')
                    else:
                        self.rx_console.write(repr(data)[1:-1])
                elif self.repr_mode == 2:
                    # escape all non-printable, including newline
                    self.rx_console.write(repr(data)[1:-1])
                elif self.repr_mode == 3:
                    # escape everything (hexdump)
                    for c in data:
                        self.rx_console.write("%s " % c.encode('hex'))
                self.rx_console.flush()
        except serial.SerialException, e:
            self.alive = False
            # would be nice if the console reader could be interruptted at this
            # point...
            raise

    def writer(self):
        try:
            while self.alive:
                try:
                    b = console.getkey()
                except KeyboardInterrupt:
                    b = serial.to_bytes([3])
                c = character(b)
                if c == EXIT_CHARACTER:
                    self.stop()
                    break                                   # exit app
                elif c == '\n':
                    self.serial.write(self.newline)         # send newline character(s)
                    if self.echo:
                        self.echo_console.write(c)          # local echo is a real newline in any case
                        self.echo_console.flush()
                else:
                    self.serial.write(b)                    # send byte
                    if self.echo:
                        self.echo_console.write(c)
                        self.echo_console.flush()
        except:
            self.alive = False
            raise


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def print_error(message):
    print >> sys.stderr, 'Error:', message


def parse_command_line():
    '''
    Return: argparse.Namespace
    '''
    parser = ArgumentParser()
    return parser.parse_args()


def print_summary(args, *initial_group):
    '''
    Print results of parsing command line
    Second argument indicates which values should be displayed at the top of
    the list.  These should typically be the destination variables for the
    positional parameters.
    '''
    keys = [name for name in dir(args) if not name.startswith('_')]
    maxkeylen = max([len(key) for key in keys])
    maxvaluelen = max([len(str(getattr(args, key))) for key in keys])
    rightcolpos = LINE_WIDTH - maxvaluelen - 2
    print '-' * LINE_WIDTH
    print 'Summary of options'
    print '-' * LINE_WIDTH
    for key in initial_group:
        print ' '+ str(key), ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    if len(initial_group):
        print
    for key in sorted(list(set(keys) - set(initial_group))):
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    print '-' * LINE_WIDTH


def key_description(character):
    """generate a readable description for a key"""
    ascii_code = ord(character)
    if ascii_code < 32:
        return 'Ctrl+%c' % (ord('@') + ascii_code)
    else:
        return repr(character)


#------------------------------------------------------------------------------
# Choose console
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

    def cleanup_console():
        sys.stderr.write("\ncleanup_console\n")
        console.cleanup()

    console.setup()
    sys.exitfunc = cleanup_console      # terminal modes have to be restored on exit...

else:
    raise NotImplementedError("Sorry no implementation for your platform (%s) available." % sys.platform)


#------------------------------------------------------------------------------
# The guts
#------------------------------------------------------------------------------

def main(args):

    convert_outgoing = CONVERT_CRLF
    if args.cr:
        convert_outgoing = CONVERT_CR
    elif args.lf:
        convert_outgoing = CONVERT_LF

    repr_mode = 0
    if args.debug:
        repr_mode = 1

    try:
        miniterm = Miniterm(args.port,
                            args.rate,
                            args.parity,
                            rtscts=args.rtscts,
                            xonxoff=args.xonxoff,
                            echo=args.echo,
                            convert_outgoing=convert_outgoing,
                            repr_mode=repr_mode)
    except serial.SerialException, e:
        sys.stderr.write("could not open port %r: %s\n" % (port, e))
        sys.exit(1)

    if not args.quiet:
        sys.stderr.write('Port ................. %s\n' % (miniterm.serial.portstr))
        sys.stderr.write('Rate ................. %s\n' % (miniterm.serial.baudrate))
        sys.stderr.write('Bits ................. %s\n' % (miniterm.serial.bytesize))
        sys.stderr.write('Parity ............... %s\n' % (miniterm.serial.parity))
        sys.stderr.write('Stop bits ............ %s\n' % (miniterm.serial.stopbits))
        sys.stderr.write('\n')
        sys.stderr.write('Quit ................. %s\n' % (key_description(EXIT_CHARACTER)))
        sys.stderr.write('\n')

    miniterm.start()
    try:
        miniterm.join(True)
    except KeyboardInterrupt:
        pass
    if not args.quiet:
        sys.stderr.write("\nExiting\n")
    miniterm.join()


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()

if args.verbose:
    print_summary(args, 'port', 'rate', 'parity', 'xonxoff', 'rtscts')
if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

main(args)

