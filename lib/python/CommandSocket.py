#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import logging
import os
import Queue
import socket
import struct
import sys
import threading

__all__ = ['Client', 'Server']


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

DEFAULT_HOST = 'localhost'
DEFAULT_PORT = 55100


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def log_debug(msg):
    logging.debug(('[%d] CommandSocket.' %
                    (threading.current_thread().ident)) + msg)


#------------------------------------------------------------------------------
# Client
#------------------------------------------------------------------------------

class Client(object):
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT):
        log_debug("Client.__init__ host '%s' port %d" % (host, port))
        self.host = host
        self.port = port
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect((self.host, self.port))
        log_debug("Client.__init__ connected")

    '''
    Send a command, and block until reply is received
    '''
    def send(self, msg):
        log_debug("Client.send msg '%s' (len %d)" % (msg, len(msg)))
        self.socket.send(struct.pack("I", len(msg)))
        self.socket.sendall(msg)
        reply_len = struct.unpack("I", self.socket.recv(4))[0]
        log_debug("Client.send len %d" % (reply_len))
        reply = self.socket.recv(reply_len)
        log_debug("Client.send reply '%s'" % (reply))
        return reply


#------------------------------------------------------------------------------
# Server
#------------------------------------------------------------------------------

class Message(object):
    def __init__(self, conn, msg):
        log_debug("Message.__init__ msg '%s'" % (msg))
        self.conn = conn
        self.msg = msg

    '''
    Send a reply, and block until client receives it
    '''
    def send_reply(self, reply):
        log_debug("Message.send_reply reply '%s'" % (reply))
        self.conn.send(struct.pack("I", len(reply)))
        self.conn.sendall(reply)


class Server(object):
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT):
        log_debug("Server.__init__ host '%s' port %d" %
                (host, port))
        self.queue = Queue.Queue(1)
        self.thread = threading.Thread(target=Server.thread_func,
                                       args=(host, port, self.queue))
        self.thread.daemon = True
        self.thread.start()

    def __del__(self):
        self.thread.join()

    def get_message(self):
        log_debug("Server.get_message")
        msg = self.queue.get()
        log_debug("Server.get_message msg '%s'" % (msg.msg))
        return msg

    @classmethod
    def thread_func(self, host, port, queue):
        log_debug("Server.thread_func host '%s' port %d" % (host, port))
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.bind((host, port))
        sock.listen(1)
        while True:
            log_debug("Server.thread_func listening")
            conn, addr = sock.accept()
            log_debug("Server.thread_func connected addr %s" % (str(addr)))
            msg_len = struct.unpack("I", conn.recv(4))[0]
            log_debug("Server.thread_func len %d" % (msg_len))
            msg = conn.recv(msg_len)
            queue.put(Message(conn, msg))

