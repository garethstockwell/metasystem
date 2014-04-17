"""
This module defines exceptions used throughout the library.
"""

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import absolute_import


#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class Error(Exception):
    def __init__(self, msg):
        super(Error, self).__init__(msg)


class UsageError(Exception):
    def __init__(self, msg):
        super(UsageError, self).__init__(msg)


class DaemonError(Error):
    def __init__(self, msg=''):
        super(DaemonError, self).__init__(msg)


class LogicError(Error):
    def __init__(self, msg=''):
        super(LogicError, self).__init__(msg)


class FilesystemError(Error):
    def __init__(self, msg):
        super(FilesystemError, self).__init__(msg)


class FileNotFoundError(FilesystemError):
    def __init__(self, path):
        msg = 'File {0:s} not found'.format(path)
        super(FileNotFoundError, self).__init__(msg)


class FileAlreadyExistsError(FilesystemError):
    def __init__(self, path):
        msg = 'File {0:s} already exists'.format(path)
        super(FileAlreadyExistsError, self).__init__(msg)


class DirectoryNotFoundError(FilesystemError):
    def __init__(self, path):
        msg = 'Directory {0:s} not found'.format(path)
        super(DirectoryNotFoundError, self).__init__(msg)


class DirectoryAlreadyExistsError(FilesystemError):
    def __init__(self, path):
        msg = 'Directory {0:s} already exists'.format(path)
        super(DirectoryAlreadyExistsError, self).__init__(msg)


class SubcommandError(Error):
    def __init__(self, args, return_code, stdout=None, stderr=None):
        self.return_code = return_code
        msg = 'Subcommand "{0:s}" returned {1:d}'.format(' '.join(args), return_code)
        if stdout:
            msg += '\nstdout:\n{0:s}'.format(stdout)
        if stderr:
            msg += '\nstderr:\n{0:s}'.format(stderr)
        super(SubcommandError, self).__init__(msg)


class NetworkError(Error):
    def __init__(self, msg):
        super(NetworkError, self).__init__(msg)


class EnvironmentError(Error):
    def __init__(self, msg):
        super(EnvironmentError, self).__init__(msg)


class InputError(Error):
    def __init__(self, msg):
        super(InputError, self).__init__(msg)

