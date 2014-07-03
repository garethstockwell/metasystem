"""
This module provides a base class for constructing UNIX daemons
"""


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import atexit
import logging
import os
import signal
import sys
import time

import metasystem
import metasystem.script
import metasystem.utils


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

MSG_WIDTH = 73

_DEFAULT_STDIN = '/dev/stdin'
_DEFAULT_STDOUT = '/dev/null'
_DEFAULT_STDERR = '/dev/null'
_DEFAULT_RAISE_STOP = False


#------------------------------------------------------------------------------
# Signal handling
#------------------------------------------------------------------------------

def _signal_swallower(signum, stack_frame):

    logging.info('Swallowing signal {0:s}'.format(str(signum)))
    signal.signal(signum, signal_swallower)


def _signal_handler(signum, stack_frame):

    # Swallow further instances of this signal
    signal.signal(signum, _signal_swallower)

    logging.info('Signal {0:s} received - exiting ...'.format(str(signum)))
    sys.exit(1)


#------------------------------------------------------------------------------
# Daemon
#------------------------------------------------------------------------------

class Daemon(object):
    """
    @param context       Object passed back to callbacks
    @param init_func     Callback made once initialized
    @param exit_func     Callback made when daemon exits
    @param raise_stop    Raise SIGSTOP once initialized
    @param exit_parent   Exit parent after fork
    """

    def __init__(self, pid_file,
                       stdin=_DEFAULT_STDIN,
                       stdout=_DEFAULT_STDOUT,
                       stderr=_DEFAULT_STDERR,
                       fg=False,
                       context=None,
                       init_func=None,
                       exit_func=None,
                       raise_stop=_DEFAULT_RAISE_STOP,
                       exit_parent=False):

        self.pid_file = pid_file

        self.stdin = stdin
        self.stdout = stdout
        self.stderr = stderr

        self.fg = fg

        self.context = context
        self.init_func = init_func
        self.exit_func = exit_func

        self.raise_stop = raise_stop

        self.exit_parent = exit_parent

        if self.fg:
            self.exit_parent = True


    def run(self):
        """
        This function must be overridden by derived classes.
        """

        raise NotImplementedError


    def start(self):

        logging.debug('Starting daemon')

        pid = self._get_pid()
        running = False
        if pid:
            try:
                logging.debug('Checking whether process {0:d} is still running'.format(pid))
                os.kill(pid, 0)
                running = True
            except Exception as e:
                logging.debug(e)
                logging.debug('Removing stale PID file')
                self._delete_pidfile()

        if running:
            raise metasystem.DaemonError('Already running with PID {0:d}'.format(pid))

        child = True

        if not self.fg:
            child = self._fork()

        if child:
            self._init()

            if not self.fg:
                self._redirect_fd()

            self.run()


    def stop(self, grace_period=2.0):

        logging.debug('Stopping daemon')

        pid = self._get_pid()
        if pid:
            logging.debug('Killing process {0:d}'.format(pid))
            try:
                os.kill(pid, signal.SIGTERM)
                time.sleep(grace_period)
                os.kill(pid, signal.SIGKILL)
            except OSError as e:
                e = str(e)
                if e.find('No such process') > 0:
                    metasystem.utils.unlink_silent(self.pid_file)
                else:
                    raise e
        else:
            logging.debug('Daemon not running')


    def restart(self, grace_period=2.0):

        logging.debug('Restarting daemon')

        self.stop(grace_period=grace_period)
        self.start()


    def _get_pid(self):

        pid = None

        if self.pid_file:
            try:
                with open(self.pid_file, 'r') as f:
                    pid = int(f.read().strip())
            except IOError:
                pass

        return pid


    def pid(self):

        pid = self._get_pid()

        try:
            logging.debug('Checking whether process {0:d} is still running'.format(pid))
            os.kill(pid, 0)
        except Exception as e:
            pid = None

        return pid


    def _delete_pidfile(self):

        if self.pid_file:
            os.remove(self.pid_file)


    def _fork(self):

        ppid = os.getpid()

        logging.debug('Forking daemon from PID {0:d}'.format(ppid))

        # First fork
        try:
            pid = os.fork()
            if pid > 0:
                sys.stdout.flush()
                sys.stderr.flush()
                if self.exit_parent is True:
                    logging.debug('Exiting first parent PID {0:d}'.format(ppid))
                    sys.exit(0)
                else:
                    # Wait for double fork to complete
                    import time
                    time.sleep(1)
                    return False
        except OSError as e:
            raise metasystem.DaemonError('First fork failed: {0:s}'.format(str(e)))

        pid = os.getpid()
        ppid = pid

        logging.debug('First fork child PID: {0:d}'.format(pid))

        # Decouple from parent
        os.chdir('/')
        os.setsid()
        os.umask(0)

        # Second fork
        try:
            pid = os.fork()
            if pid > 0:
                logging.debug('Exiting second parent PID {0:d}'.format(ppid))
                sys.stdout.flush()
                sys.stderr.flush()
                sys.exit(0)
        except OSError as e:
            raise metasystem.DaemonError('Second fork failed: {0:s}'.format(str(e)))

        pid = os.getpid()
        logging.debug('Second fork child PID: {0:d}'.format(pid))

        return True


    def _init(self):

        # Install signal handler
        logging.debug('Installing signal handler')
        signal.signal(signal.SIGTERM, _signal_handler)

        # Register cleanup function
        logging.debug('Registering atexit function')
        atexit.register(self._delete_pidfile)

        pid = os.getpid()

        # Write pidfile
        if self.pid_file:
            logging.debug('Writing PID to {0:s}'.format(self.pid_file))
            with open(self.pid_file, 'w+') as f:
                f.write('{0:d}\n'.format(pid))

        if self.init_func:
            self.init_func(self, self.context)

        if self.raise_stop:
            os.kill(pid, signal.SIGSTOP)


    def _redirect_fd(self):

        logging.debug('Redirecting file descriptors')
        # Ensure nothing is written to stdout/stderr past this point
        sys.stdout.flush()
        sys.stderr.flush()
        si = file(self.stdin, 'r')
        so = file(self.stdout, 'a+')
        se = file(self.stderr, 'a+', 0)
        os.dup2(si.fileno(), sys.stdin.fileno())
        os.dup2(so.fileno(), sys.stdout.fileno())
        os.dup2(se.fileno(), sys.stderr.fileno())



#------------------------------------------------------------------------------
# ArgumentParser
#------------------------------------------------------------------------------

class ArgumentParser(metasystem.script.ArgumentParser):

    def __init__(self, description='', epilog='', version=0.1):
        metasystem.script.ArgumentParser.__init__(self,
                                             description = description,
                                             epilog = epilog)

        subparsers = self.add_subparsers(help='subcommands',
                                         parser_class=argparse.ArgumentParser)

        start = subparsers.add_parser('start')
        start.set_defaults(func=Program._daemon_start)

        start.add_argument('--fg',
                           action='store_true',
                           dest='daemon_fg',
                           default=False,
                           help='do not fork to background')

        start.add_argument('--stop',
                           action='store_true',
                           dest='daemon_raise_stop',
                           default=_DEFAULT_RAISE_STOP,
                           help='raise SIGSTOP once initialized')

        stop = subparsers.add_parser('stop')
        stop.set_defaults(func=Program._daemon_stop)

        restart = subparsers.add_parser('restart')
        restart.set_defaults(func=Program._daemon_restart)

        status = subparsers.add_parser('status')
        status.set_defaults(func=Program._daemon_status)

        self.add_argument('--show-info',
                          dest='daemon_show_info',
                          action='store_true',
                          default=False,
                          help='show startup/shutdown info')

        self.add_argument('--pidfile',
                          metavar='FILE',
                          dest='pid_file',
                          help='PID filename')

        self.add_argument('--stdin',
                          dest='stdin',
                          default=_DEFAULT_STDIN,
                          help='STDIN')

        self.add_argument('--stdout',
                          dest='stdout',
                          default=_DEFAULT_STDOUT,
                          help='STDOUT')

        self.add_argument('--stderr',
                          dest='stderr',
                          default=_DEFAULT_STDERR,
                          help='STDERR')


#------------------------------------------------------------------------------
# Info
#------------------------------------------------------------------------------

class Info(object):
    '''
    If an instance of this class is assigned to daemon.Program.daemon_info, the
    daemon prints messages like this:
    * metasystem-foo: starting                                 [ OK ]
    '''

    def __init__(self, name, msg=None):

        self.name = name
        self.msg = msg


#------------------------------------------------------------------------------
# Program
#------------------------------------------------------------------------------

class Program(metasystem.script.Program):
    """
    Daemon base class
    """

    def __init__(self, parser):

        metasystem.script.Program.__init__(self, parser)

        self.daemon_info = None
        self._daemon_action = False


    def _daemon_action_open(self, action):

        assert self._daemon_action is False

        if self.daemon_info and self.args.daemon_show_info:
            output = ' * {0:s}: {1:s}'.format(self.daemon_info.name, action)
            if self.daemon_info.msg:
                output += ' ' + self.daemon_info.msg
            output += ' ' * (MSG_WIDTH - len(output))
            sys.stdout.write(output)
            sys.stdout.flush()
            self._daemon_action = True


    def _daemon_action_close(self, ok):

        if self._daemon_action and self.args.daemon_show_info:
            msg = { True: 'OK', False: 'FAILED' }.get(ok)
            sys.stdout.write('[ {0:s} ]\n'.format(msg))
            self._daemon_action = False


    def init(self):

        metasystem.script.Program.init(self, do_init=False)

        if not self.args.pid_file:
            if self.args.func != Program._daemon_start or not self.args.daemon_fg:
                msg = 'Cannot perform action without --pidfile'
                raise metasystem.DaemonError(msg)

        fg = False
        if self.args.func == Program._daemon_start:
            fg = self.args.daemon_fg

        raise_stop = False
        if self.args.func == Program._daemon_start:
            raise_stop = self.args.daemon_raise_stop

        self._daemon = Daemon(pid_file=self.args.pid_file,
                              stdin=self.args.stdin,
                              stdout=self.args.stdout,
                              stderr=self.args.stderr,
                              fg=fg,
                              context=self,
                              init_func=self._daemon_init_callback,
                              raise_stop=raise_stop,
                              exit_parent=True)

        self._daemon.run = self.do_run

        self.args.func(self)


    def run(self):

        self.init()
        self.exit()


    def cleanup(self):

        super(Program, self).cleanup()
        logging.debug('daemon.Program.cleanup')
        pass


    @staticmethod
    def _daemon_init_callback(daemon, program):

        program.do_init()
        program._daemon_action_close(True)


    def _daemon_start(self):

        logging.debug('Starting daemon')
        self._daemon_action_open('starting')
        self._daemon.start()


    def _daemon_stop(self, grace_period=2.0):

        self._daemon_action_open('stopping')
        self._daemon.stop(grace_period=grace_period)
        self._daemon_action_close(True)
        sys.exit(0)


    def _daemon_restart(self, grace_period=2.0):

        logging.debug('Restarting daemon')
        self._daemon_action_open('restarting')
        self._daemon.restart(grace_period=grace_period)
        self._daemon_action_close('True')


    def _daemon_status(self):

        pid = self._daemon.pid()
        if pid:
           logging.info('{0:d}'.format(pid))
        else:
            logging.info('Not running')
        sys.exit(0)

