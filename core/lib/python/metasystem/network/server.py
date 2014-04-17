"""
This module provides building blocks for constructing client-server systems.
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import os
import logging
import pickle
import Queue
import socket
import struct
import sys
import threading
import traceback

import tzmpp


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

DEFAULT_HOST = 'localhost'


#------------------------------------------------------------------------------
# Message
#------------------------------------------------------------------------------

class Message(object):
    '''
    Message sent from client to server
    '''

    def __init__(self, conn, payload):
        '''
        @param conn         socket
        @param payload      any object
        '''

        self._conn = conn
        self.payload = payload


    def send_reply(self, payload):
        '''
        Send response back to client
        @param payload      any object
        '''

        self._send_reply(payload=payload)


    def send_error(self, error):
        '''
        Send error back to client
        @param error        exception object
        '''

        error_msg = traceback.format_exc(error)
        logging.debug('error {0:s}'.format(error_msg))
        self._send_reply(error=error_msg)


    def _send_reply(self, payload=None, error=None):
        '''
        Send a reply, and block until client receives it
        '''

        tx_obj = Reply(payload=payload, error=error)
        tx_data = pickle.dumps(tx_obj)
        tx_len = len(tx_data)

        self._conn.send(struct.pack('I', tx_len))
        self._conn.sendall(tx_data)


#------------------------------------------------------------------------------
# Reply
#------------------------------------------------------------------------------

class Reply(object):
    '''
    Reply sent from server to client
    '''

    def __init__(self, payload, error=None):

        self.payload = payload
        self.error = error


#------------------------------------------------------------------------------
# Client
#------------------------------------------------------------------------------

class Client(object):

    def __init__(self, port, host=DEFAULT_HOST):

        self.host = host
        self.port = port


    def send(self, payload):
        '''
        Send a message, and block until reply is received

        @param payload          any object
        @returns                any object
        '''

        result = None

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.connect((self.host, self.port))

            tx_data = pickle.dumps(payload)
            tx_len = len(tx_data)
            sock.send(struct.pack('I', len(tx_data)))
            sock.sendall(tx_data)

            rx_len = struct.unpack('I', sock.recv(4))[0]
            rx_data = sock.recv(rx_len)

            rx_obj = pickle.loads(rx_data)

            if isinstance(rx_obj, Reply):
                if rx_obj.error is None:
                    result = rx_obj.payload
                else:
                    raise tzmpp.NetworkError, rx_obj.error
            else:
                raise tzmpp.NetworkError, 'Received malformed reply'

        finally:
            sock.close()

        return result


#------------------------------------------------------------------------------
# Server
#------------------------------------------------------------------------------

class Server(object):

    def __init__(self, port, host=DEFAULT_HOST):

        self.queue = Queue.Queue(1)
        self.run = [True]

        self.host = host
        self.port = port

        self.thread = threading.Thread(target=self.thread_func,
                                       args=(self.run, self.host, self.port, self.queue))
        self.thread.daemon = True


    def start(self):

        self.run[0] = True
        self.thread.start()


    def stop(self):

        self.run[0] = False
        self.thread.join()


    def running(self):

        return self.run[0]


    def get_message(self, block=True, timeout=None):
        '''
        Pop a message off the queue.

        @return Message or None
        '''

        msg = None
        try:
            msg = self.queue.get(block, timeout)
        except Queue.Empty:
            pass
        return msg


    @classmethod
    def thread_func(self, run, host, port, queue):

        logging.debug('Server.thread_func host {0:s} port {1:d}'.format(host, port))

        socket.setdefaulttimeout(1.0)

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((host, port))
        sock.listen(1)

        while True:
            if run[0] is False:
                return

            try:
                conn, addr = sock.accept()
                logging.debug('Server.thread_func addr {0:s}'.format(str(addr)))

                rx_len = struct.unpack('I', conn.recv(4))[0]
                rx_data = conn.recv(rx_len)

                rx_payload = pickle.loads(rx_data)

                queue.put(Message(conn, rx_payload))

            except socket.timeout:
                pass

            except Exception, e:
                logging.error(e)
                logging.error('Received malformed message from {0:s}'.format(str(addr)))

