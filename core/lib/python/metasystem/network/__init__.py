"""
This module provides various utilities concerned with networking.

These include:
    - Querying the properties (IP address, mask etc) of specified interfaces
    - Determination of the IP address of the target from the host, and vice
      versa
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import absolute_import

import datetime
import re
import logging
import os
import pickle
import socket
import struct

import metasystem.utils


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

DEFAULT_IF_NAME = 'eth0'

class ServicePortSpec(object):

    def __init__(self, base, count):

        self.base = base
        self.count = count


#------------------------------------------------------------------------------
# Network services
#------------------------------------------------------------------------------

class NetworkService(object):

    Type = metasystem.utils.enum(MANDATORY='mandatory',
                            OPT_IN='opt_in',
                            OPT_OUT='opt_out')

    def __init__(self, name, type, primary_base_port, secondary_base_port, count=1):
        """
        Define a service exposed by a secondary OS

        @param name                  Name for the service
        @param type                  Service type
        @param primary_base_port     Base port for the service on the primary OS
        @param secondary_base_port   Base port for this service on the secondary OS
        @param count                 Maximum number of instances of the service
        """
        self.name = name
        self.type = type
        self._primary_base_port = primary_base_port
        self._secondary_base_port = secondary_base_port
        self.count = count


    def _check_args(self, os_index, instance):

        if instance >= self.count:
            raise metasystem.Error("Instance {0:d} out of range for service {1:s}".format(
                              instance, self.name))


    def primary_port(self, os_index, instance=0):
        """
        Returns port open on the primary OS

        @param os_index     Index of the OS exposing the service
        @param instance     Index of the service instance exposed
        """
        self._check_args(os_index, instance)
        return self._primary_base_port + (os_index * self.count) + instance


    def secondary_port(self, os_index, instance=0):
        """
        Returns port open on the secondary OS

        @param os_index     Index of the OS exposing the service
        @param instance     Index of the service instance exposed
        """
        self._check_args(os_index, instance)
        return self._secondary_base_port + instance


_SERVICES = {
    'adb':     (NetworkService.Type.OPT_IN,    10000, 5555, 1),
    'gdb':     (NetworkService.Type.OPT_OUT,   10100, 1234, 10),
    'monitor': (NetworkService.Type.OPT_IN,    10200, 4444, 1),
    'ssh':     (NetworkService.Type.OPT_OUT,   10300,   22, 1),
}


def all_services():

    return [ service(name) for name in _SERVICES ]


def default_service_names():

    return [ s.name for s in all_services() if s.type != NetworkService.Type.OPT_IN ]


def service(name):

    if not name in _SERVICES:
        raise metasystem.Error('Service {0:s} not recognized'.format(name))

    entry = _SERVICES[name]
    return NetworkService(name, *entry)


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

import platform
if platform.system() == 'Linux':

    import fcntl

    SIOCGIFNETMASK = 0x891b
    SIOCGIFADDR = 0x8915

    def mask(ifname=DEFAULT_IF_NAME):
        """
        Query the network mask of a specified interface

        Only works on UNIX
        """

        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        mask = fcntl.ioctl(s, SIOCGIFNETMASK, struct.pack('256s', ifname))[20:24]
        return socket.inet_ntoa(mask)


    def ip_addr(ifname=DEFAULT_IF_NAME):
        """
        Query the IP address of a specified interface

        Only works on UNIX
        """

        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        addr = None
        try:
            addr = socket.inet_ntoa(fcntl.ioctl(
                s.fileno(),
                SIOCGIFADDR,
                struct.pack('256s', ifname[:15])
            )[20:24])
        except:
            pass

        return addr


    def bcast_addr(ifname=DEFAULT_IF_NAME):
        """
        Query the broadcast address of a specified interface

        Only works on UNIX
        """

        return '.'.join(ip_addr(ifname).split('.')[0:3] + ['255'])


    def gw_addr(ifname=DEFAULT_IF_NAME):
        """
        Query the gateway address of a specified interface

        Only works on UNIX
        """

        cmd = "ip route list dev " + ifname + " | awk ' /^default/ {print $3}'"
        fin, fout = os.popen4(cmd)
        result = fout.read()
        return result.strip()


    def hw_addr(ifname=DEFAULT_IF_NAME):
        """
        Query the hardware (MAC) address of a specified interface

        Only works on UNIX
        """

        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        info = fcntl.ioctl(s.fileno(), 0x8927,  struct.pack('256s', ifname[:15]))
        return ''.join(['%02x:' % ord(char) for char in info[18:24]])[:-1]

else:

    def mask(ifname=DEFAULT_IF_NAME):

        return None


    def ip_addr(ifname=DEFAULT_IF_NAME):

        return socket.gethostbyname(socket.gethostname())


    def bcast_addr(ifname=DEFAULT_IF_NAME):

        return None


    def gw_addr(ifname=DEFAULT_IF_NAME):

        return None


    def hw_addr(ifname=DEFAULT_IF_NAME):

        return None


#------------------------------------------------------------------------------
# Cross-platform functions
#------------------------------------------------------------------------------

def domain():

    return socket.getfqdn().replace(socket.gethostname()+'.', '')


def fqdn():

    return socket.getfqdn()


def hostname():

    return socket.gethostname()


def get_ip_addr(fqdn):
    """
    Get IP address of specified machine
    """

    client = NetworkConfigClient()
    result = client.request()
    logging.debug('Received {0:d} configurations'.format(len(result)))
    for r in result:
        if r.fqdn == fqdn:
            return r.ip_addr

    return None


#------------------------------------------------------------------------------
# NetworkConfig
#------------------------------------------------------------------------------

class NetworkConfig(object):
    """
    Container for all properties of a specified network interface
    """

    def __init__(self):

        self._reset()


    def _reset(self):

        self.if_name = None
        self.ip_addr = None
        self.bcast_addr = None
        self.mask = None
        self.gw_addr = None
        self.hw_addr = None
        self.cookie = None


    def get(self, if_name=DEFAULT_IF_NAME):

        try:
            self.if_name = if_name
            self.ip_addr = ip_addr(if_name)
            self.bcast_addr = bcast_addr(if_name)
            self.mask = mask(if_name)
            self.gw_addr = gw_addr(if_name)
            self.hw_addr = hw_addr(if_name)
            return True
        except:
            self._reset()
            return False


    def __repr__(self):

        formatter = metasystem.utils.KeyValueFormatter()
        result = ''
        result += formatter.format('if_name', str(self.if_name)) + '\n'
        result += formatter.format('ip_addr', str(self.ip_addr)) + '\n'
        result += formatter.format('bcast_addr', str(self.bcast_addr)) + '\n'
        result += formatter.format('mask', str(self.mask)) + '\n'
        result += formatter.format('gw_addr', str(self.gw_addr)) + '\n'
        result += formatter.format('hw_addr', str(self.hw_addr)) + '\n'
        result += formatter.format('cookie', str(self.cookie)) + '\n'
        return result.rstrip()


#------------------------------------------------------------------------------
# NetworkConfigServer
#------------------------------------------------------------------------------

"""
UDP ports used by NetworkConfigServer, NetworkConfigClient
"""
DEFAULT_CONFIG_REQUEST_PORT = 50000
DEFAULT_CONFIG_REPLY_PORT = 50001

class NetworkConfigRequest(object):

    def __init__(self):

        pass


class NetworkConfigServer(object):

    """
    Broadcasts the NetworkConfig of the current machine via UDP multicast.
    """

    def __init__(self, cookie=None):

        self.rx_sock = None
        self.tx_sock = None
        self.request_port = None
        self.if_name = None
        self.cookie = cookie


    def init(self, request_port=DEFAULT_CONFIG_REQUEST_PORT,
                   reply_port=DEFAULT_CONFIG_REPLY_PORT,
                   if_name=DEFAULT_IF_NAME):

        assert self.rx_sock is None
        assert self.tx_sock is None

        self.rx_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rx_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.rx_sock.bind(('', request_port))

        self.tx_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.tx_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.tx_sock.bind(('', 0))

        self.request_port = request_port
        self.reply_port = reply_port
        self.if_name = if_name


    def listen(self):

        assert self.rx_sock is not None
        assert self.tx_sock is not None

        while True:
            logging.debug('Listening on port {0:d}'.format(self.request_port))
            rx_data, rx_addr = self.rx_sock.recvfrom(1024)
            rx_payload = pickle.loads(rx_data)

            if isinstance(rx_payload, NetworkConfigRequest):
                logging.debug('Received request from {0:s}'.format(rx_addr))

                config = NetworkConfig()
                if not config.get(self.if_name):
                    msg = 'Failed to get configuration for interface {0:s}'.format(self.if_name)
                    raise metasystem.NetworkError(msg)

                config.cookie = self.cookie

                logging.debug('Broadcasting on port {0:d}:'.format(self.reply_port))
                logging.debug(config)

                tx_payload = pickle.dumps(config)
                self.tx_sock.sendto(tx_payload, ('<broadcast>', self.reply_port))

            else:
                logging.debug('Received malformed message from {0:s}'.format(rx_addr))


#------------------------------------------------------------------------------
# NetworkConfigClient
#------------------------------------------------------------------------------

class NetworkConfigClient(object):

    """
    Receives the NetworkConfig of other machines which are broadcasting via
    UDP multicast.
    """

    DEFAULT_TX_TIMEOUT = 1.0
    DEFAULT_RX_TIMEOUT = 1.0

    def __init__(self, cookie=None):

        self.cookie = cookie


    def request(self, request_port=DEFAULT_CONFIG_REQUEST_PORT,
                      reply_port=DEFAULT_CONFIG_REPLY_PORT,
                      tx_timeout=DEFAULT_TX_TIMEOUT,
                      rx_timeout=DEFAULT_RX_TIMEOUT):
        """
        Returns an array of NetworkConfig objects
        """

        socket.setdefaulttimeout(tx_timeout)

        tx_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        tx_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        tx_sock.bind(('', 0))

        request = NetworkConfigRequest()
        tx_payload = pickle.dumps(request)

        logging.debug('Sending via port {0:d}'.format(request_port))
        tx_sock.sendto(tx_payload, ('<broadcast>', request_port))
        tx_sock.close()

        socket.setdefaulttimeout(rx_timeout)

        rx_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        rx_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        rx_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        rx_sock.bind(('', reply_port))

        start = datetime.datetime.now()

        result = []

        while True:

            delta = datetime.datetime.now() - start
            if rx_timeout != 0 and delta.seconds >= rx_timeout:
                break

            try:
                logging.debug('Listening on port {0:d}'.format(reply_port))
                rx_data, rx_addr = rx_sock.recvfrom(1024)
                rx_payload = pickle.loads(rx_data)

                if isinstance(rx_payload, NetworkConfig):
                    ip_addr = rx_payload.ip_addr
                    exists = False
                    for entry in result:
                        if entry.ip_addr == ip_addr:
                            assert entry.hw_addr == rx_payload.hw_addr
                            exists = True

                    if not exists:
                        logging.debug('Received from {0:s}:'.format(rx_addr))
                        logging.debug(rx_payload)

                        if self.cookie is None or rx_payload.cookie == self.cookie:
                            result.append(rx_payload)

                else:
                    logging.debug('Received malformed message from {0:s}'.format(rx_addr))

            except socket.error as e:
                logging.debug(e)
                break

        return result

