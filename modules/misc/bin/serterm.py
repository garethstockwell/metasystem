#!/usr/bin/env python

# serterm

# Simple serial terminal
# Based on miniterm example, part of PySerial distribution

# TODO
# * Allow filters to be loaded dynamically
# * Add 'write to file' option


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import logging
import os
import serial
import sys
import threading

sys.path.append(os.path.join(os.environ.get('METASYSTEM_CORE_LIB'), 'python'))
from metasystem import console
from metasystem import commandsocket
from metasystem import threading


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80

EXIT_CHARACTER = '\x1d'   # GS/CTRL+]


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

        subparsers = self.add_subparsers(help='subcommands',
                                         parser_class=argparse.ArgumentParser)

        parser_connect = subparsers.add_parser('connect', help='Connect to serial port')
        parser_connect.add_argument('port',
                                    metavar='PORT',
                                    help='Port')
        parser_connect.add_argument('rate',
                                    metavar='RATE',
                                    help='Baud rate (default {0})'.format(self.DEFAULT_RATE),
                                    nargs='?',
                                    default=self.DEFAULT_RATE)
        parser_connect.add_argument('-p', '--parity',
                                    dest='parity',
                                    action='store',
                                    default='N',
                                    help="parity [N, E, O, S, M] (default N)")
        parser_connect.add_argument('--xonxoff',
                                    dest='xonxoff',
                                    action='store_true',
                                    default=False,
                                    help="enable software flow control (default off)")
        parser_connect.add_argument('--rtscts',
                                    dest='rtscts',
                                    action='store_true',
                                    default=False,
                                    help="enable RTS/CTS flow control (default off)")
        parser_connect.add_argument('--echo',
                                    dest='echo',
                                    action='store_true',
                                    default=False,
                                    help="enable echo (default off)")
        parser_connect.add_argument('--cr',
                                    dest='cr',
                                    action='store_true',
                                    default=False,
                                    help="do not sent CR+LF, send CR only")
        parser_connect.add_argument('--lf',
                                    dest='lf',
                                    action='store_true',
                                    default=False,
                                    help="do not send CR+LF, send LF only")
        parser_connect.add_argument('--command-port',
                                    dest='command_port',
                                    action='store',
                                    help='port on which to listen for commands',
                                    default=None)
        parser_connect.set_defaults(func=do_connect)

        parser_send = subparsers.add_parser('send', help='Send message to console')
        parser_send.add_argument('cmd',
                                 metavar='COMMAND',
                                 help='command',
                                 nargs='+')
        parser_send.add_argument('--host',
                                 dest='command_host',
                                 action='store',
                                 help='host',
                                 default=None)
        parser_send.add_argument('--port',
                                 dest='command_port',
                                 action='store',
                                 help='port',
                                 default=None)
        parser_send.set_defaults(func=do_send)


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def log_debug(msg):
    logging.debug(('[%d] serterm ' %
                    (threading.current_thread().ident)) + msg)


# http://stackoverflow.com/questions/36932/whats-the-best-way-to-implement-an-enum-in-python
def enum(*sequential, **named):
    enums = dict(zip(sequential, range(len(sequential))), **named)
    return type('Enum', (), enums)


def write_stdout(msg, fg=None):
    if fg:
        sys.stdout.state.push()
        sys.stdout.state.set_fg(fg)
    sys.stdout.write(msg)
    if fg:
        sys.stdout.state.pop()


#------------------------------------------------------------------------------
# Filter
#------------------------------------------------------------------------------

class Filter(object):
    def __init__(self, miniterm):
        self.enabled = True
        self.miniterm = miniterm

    def filter(self, msg):
        pass

    def command(self, tokens):
        log_debug("Filter.command %s" % (str(tokens)))
        return 'Not implemented'


'''
Filter which handles ANSI control codes
For SGR codes, the provided OutputStreamState is modified appropriately
Other codes are removed from the stream

http://en.wikipedia.org/wiki/ANSI_escape_code
'''
class AnsiFilter(Filter):
    ESC = '\x1b'
    CSI = '['

    State = enum('BASE', 'ESC', 'CSI')

    @classmethod
    def name(self):
        return 'ansi'

    def __init__(self, miniterm, console_state):
        log_debug("AnsiFilter.__init__")
        Filter.__init__(self, miniterm)
        self.console_state = console_state
        self.state = AnsiFilter.State.BASE
        self.csi_buf = ''
        self.out_buf = ''

    def filter(self, msg):
        self.out_buf = ''
        for char in msg:
            #log_debug("AnsiFilter.filter char '%s'" % (char))
            {AnsiFilter.State.BASE: AnsiFilter._handle_base,
             AnsiFilter.State.ESC:  AnsiFilter._handle_esc,
             AnsiFilter.State.CSI:  AnsiFilter._handle_csi
            }.get(self.state)(self, char)
        #log_debug("AnsiFilter.filter out '%s'" % (self.out_buf))
        return self.out_buf

    def _handle_base(self, char):
        #log_debug("AnsiFilter._handle_base")
        if char == AnsiFilter.ESC:
            self.state = AnsiFilter.State.ESC
        else:
            self.out_buf += char

    def _handle_esc(self, char):
        #log_debug("AnsiFilter._handle_esc")
        if char == AnsiFilter.CSI:
            self.csi_buf = ''
            self.state = AnsiFilter.State.CSI
        else:
            # Ignore single-char code
            self.state = AnsiFilter.State.BASE

    def _handle_csi(self, char):
        #log_debug("AnsiFilter._handle_csi")
        if str.isdigit(char) or char == ';':
            self.csi_buf += char
        elif char == 'm':
            self._handle_sgr()
            self.state = AnsiFilter.State.BASE
        else:
            # Ignore other CSI
            self.state = AnsiFilter.State.BASE

    def _handle_sgr(self):
        #log_debug("AnsiFilter._handle_sgr '%s'" % (self.csi_buf))
        if self.csi_buf == '0':
            self.console_state.reset()
        else:
            rs = console.Ansi.ansi_to_renderstate(self.csi_buf)
            self.console_state.set(rs)


'''
Filter which searches for a single string in the stream
'''
class SimpleMatchFilter(Filter):
    def __init__(self, miniterm, pat):
        Filter.__init__(self, miniterm)
        self.idx = -1
        self.pat = pat

    def filter(self, msg):
        for i in range(0, len(msg)):
            idx = self.idx + 1
            if msg[i] == self.pat[idx]:
                self.idx = idx
                if self.idx+1 == len(self.pat):
                    self.match()
                    self.idx = -1
            else:
                self.idx = -1
        return msg

    def match(self):
        pass


'''
Filter which sends newlines to the bootloader, to enter u-boot mode, then
sends the fastboot command.
'''
class UbootFastbootFilter(SimpleMatchFilter):
    def __init__(self, miniterm):
        log_debug("UbootFastbootFilter.__init__")
        SimpleMatchFilter.__init__(self, miniterm, 'u-boot>')
        self.enabled = False
        self.timer = None

    @classmethod
    def name(self):
        return 'uboot-fastboot'

    def match(self):
        log_debug("UbootFastbootFilter.match")
        self.disable()
        write_stdout('\n[UbootFastbootFilter] Sending fastboot ...\n\n', console.Color.RED)
        self.miniterm.serial.write('fastboot')
        self.miniterm.serial.write(self.miniterm.newline)

    def command(self, tokens):
        log_debug("UbootFastbootFilter.command %s" % (str(tokens)))
        reply = 'Command not supported'
        if len(tokens):
            if tokens[0] == 'on':
                log_debug("UbootFastbootFilter.command on")
                self.enable()
                reply = 'OK'
            elif tokens[0] == 'off':
                log_debug("UbootFastbootFilter.command off")
                self.disable()
                reply = 'OK'
        return reply

    def send_newline(self):
        log_debug("UbootFastbootFilter.send_newline")
        write_stdout('\n[UbootFastbootFilter] Sending newline ...\n\n', console.Color.RED)
        self.miniterm.serial.write(self.miniterm.newline)

    def enable(self):
        if not self.timer:
            self.timer = threading.RepeatTimer(0.5, self.send_newline)
            self.timer.daemon = True
            self.timer.start()
        self.enabled = True

    def disable(self):
        if self.timer:
            self.timer.cancel()
            self.timer.join()
            self.timer = None
        self.enabled = False


class FilterChain(object):
    def __init__(self):
        self.filters = []

    def append(self, f):
        if self.find_filter(f.name()):
            raise Exception, 'Filter %s is already in the chain' % (f.name())
        self.filters.append(f)

    def find_filter(self, key):
        for f in self.filters:
            if f.name() == key:
                return f
        return None

    def filter(self, msg):
        for f in self.filters:
            if f.enabled:
                msg = f.filter(msg)
        return msg


class FilterFactory(object):
    def __init__(self, miniterm):
        self.classes = {}
        self.miniterm = miniterm

    def register(self, cls):
        key = cls.name()
        log_debug("FilterFactory.register cls %s key %s" % (str(cls), key))
        self.classes[key] = cls

    def build(self, key):
        obj = None
        if key in self.classes.keys():
            obj = self.classes[key](self.miniterm)
            log_debug("FilterFactory.build key %s obj %s" % (key, str(obj)))
        else:
            log_debug("FilterFactory.build key %s not found" % (key))
        return obj


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
    def __init__(self, port, baudrate, parity, rtscts, xonxoff, echo=False, convert_outgoing=CONVERT_CRLF, repr_mode=0, command_port=None):
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
        if command_port:
            command_port = int(command_port)
        self.command_server = commandsocket.Server(port=command_port)
        self.rx_state = console.OutputStreamState()
        #self.rx_state.set_fg(console.Color.GREEN)
        #self.rx_state.save_default()
        self._init_filters()

    def _init_filters(self):
        self.filter_factory = FilterFactory(self)
        # TODO: do this by introspection
        self.filter_factory.register(UbootFastbootFilter)
        self.filter_chain = FilterChain()
        if os.name == 'nt':
            self.filter_chain.append(AnsiFilter(self, self.rx_state))
        # TODO: accept a command-line parameter specifying the filters to load
        self.filter_chain.append(self.filter_factory.build('uboot-fastboot'))

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

    def loop(self, transmit_only=False):
        while self.alive:
            msg = self.command_server.get_message(block=True, timeout=0.05)
            if msg:
                self.handle_msg(msg)
        self.join(transmit_only)

    def handle_msg(self, msg):
        log_debug("handle_msg %s" % (msg.msg))
        tokens = msg.msg.split(' ')
        name = tokens.pop(0)
        filter = self.filter_chain.find_filter(name)
        if filter:
            reply = filter.command(tokens)
            msg.send_reply(reply)
        else:
            log_debug("handle_msg filter %s not found" % (name))
            msg.send_reply('Filter %s not found' % (name))

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

    def write_rx(self, msg):
        sys.stdout.state.push()
        sys.stdout.state.set(self.rx_state.current)
        sys.stdout.write(msg)
        sys.stdout.state.pop()

    def write_echo(self, msg):
        sys.stdout.state.push()
        sys.stdout.state.set_fg(console.Color.YELLOW)
        sys.stdout.write(msg)
        sys.stdout.state.pop()

    def reader(self):
        try:
            while self.alive and self._reader_alive:
                data = character(self.serial.read(1))

                if data:
                    data = self.filter_chain.filter(data)

                if self.repr_mode == 0:
                    # direct output, just have to care about newline setting
                    if data == '\r' and self.convert_outgoing == CONVERT_CR:
                        self.write_rx('\n')
                    else:
                        self.write_rx(data)
                elif self.repr_mode == 1:
                    # escape non-printable, let pass newlines
                    if self.convert_outgoing == CONVERT_CRLF and data in '\r\n':
                        if data == '\n':
                            self.write_rx('\n')
                        elif data == '\r':
                            pass
                    elif data == '\n' and self.convert_outgoing == CONVERT_LF:
                        self.write_rx('\n')
                    elif data == '\r' and self.convert_outgoing == CONVERT_CR:
                        self.write_rx('\n')
                    else:
                        self.write_rx(repr(data)[1:-1])
                elif self.repr_mode == 2:
                    # escape all non-printable, including newline
                    self.write_rx(repr(data)[1:-1])
                elif self.repr_mode == 3:
                    # escape everything (hexdump)
                    for c in data:
                        self.write_rx("%s " % c.encode('hex'))
                sys.stdout.flush()

        except serial.SerialException, e:
            self.alive = False
            # would be nice if the console reader could be interruptted at this
            # point...
            raise

    def writer(self):
        try:
            while self.alive:
                try:
                    b = sys.stdin.get_key()
                except KeyboardInterrupt:
                    b = serial.to_bytes([3])
                c = character(b)
                if c == EXIT_CHARACTER:
                    self.stop()
                    break                                   # exit app
                elif c == '\n':
                    self.serial.write(self.newline)         # send newline character(s)
                    if self.echo:
                        self.write_echo(c)          # local echo is a real newline in any case
                        sys.stdout.flush()
                else:
                    self.serial.write(b)                    # send byte
                    if self.echo:
                        self.write_echo(c)
                        sys.stdout.flush()
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
# The guts
#------------------------------------------------------------------------------

def do_connect(args):
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
                            repr_mode=repr_mode,
                            command_port=args.command_port)
    except serial.SerialException, e:
        sys.stderr.write("could not open port %r: %s\n" % (args.port, e))
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
        miniterm.loop()
    except KeyboardInterrupt:
        pass
    if not args.quiet:
        sys.stderr.write("\nExiting\n")
    miniterm.join()


def do_send(args):
    host = args.command_host
    port = args.command_port
    if port:
        port = int(port)
    client = commandsocket.Client(host=host, port=port)
    msg = ' '.join(args.cmd)
    print "Client: sending '" + msg + "'"
    reply = client.send(msg)
    print "Reply: '" + reply + "'"


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()

if args.verbose:
    print_summary(args, 'port', 'rate', 'parity', 'xonxoff', 'rtscts')
if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

args.func(args)

