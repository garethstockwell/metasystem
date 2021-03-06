#!/usr/bin/env python2

# Syncs dynamic content managed by SCM systems (git, hg), rsync and unison
#
# A list of projects are defined in an INI file.  Each project has the
# following attributes:
#
#     Required attributes:
#
#         type = git | hg | rsync | unison
#
#         path
#             Path to the project, relative to the local / remote root paths.
#
#         auto = true | false
#             Determines whether the project is synchronised automatically.
#             If true, the project is synchronised when 'metasystem-sync.py' is run
#             without any arguments.  If false, the project name must be
#             explicitly stated, e.g. 'metasystem-sync.py foo'.
#
#    Optional attributes:
#
#         direction = pull | push | both
#             Determines the direction(s) in which data is transferred.
#             Not valid for 'type = unison' projects.
#
#         branches
#             List of branches which are synchronised.
#             Only valid for 'type = git' projects.
#
#         subdirs
#             Subdirectories which are synchronised.  If not specified, all
#             subdirectories are synchronised by default.  This can be
#             overridden on the command line - for example, to synchronise only
#             subdirectory x from project foo, run 'metasystem-sync.py foo/x'.
#             Only valid for 'type = rsync | unison' projects.
#
# Example project definitions:
#
#    [project:foo]
#    type = git
#    local_path = git/foo
#    remote = my-gitorious
#    remote_path = git/foo
#    auto = true
#    direction = pull
#    branches = a b
#
#    [project:bar]
#    type = unison
#    local_path = unison/bar
#    remote = usb-drive
#    remote_path = unison/bar
#    auto = false
#    subdirs = x y
#
# The INI file also defines a list of locals, which are mappings from computer
# HOSTNAME variables to friendly labels, for example
#
#    [local:my-desktop]
#    hostname = Desktop.1027.domain.blah
#    root = /home/me/some/folder
#
# Local-specific project attributes may be specified in order to control
# which content gets synchronised to each host, for example:
#
#    [project:bar]
#    type = unison
#    path = unison/bar
#    auto = false
#    subdirs(my-desktop) = common-folder desktop-only-folder
#    subdirs(my-laptop) = common-folder laptop-only-folder
#
# Remotes are specified like this:
#
#    [remote:my-gitorious]
#    root = ssh://me@some.gitorious.server:22
#    scm_bare = true
#
# See $METASYSTEM_CORE_CONFIG/sync.ini for an example INI file.

#------------------------------------------------------------------------------
# TODO
#------------------------------------------------------------------------------

# Definitely
# * Named options for Execute:
#   - 'execute' - specifies whether to just print the command, or also to run it
#   - 'suppress' - specifies whether to ignore errors, e.g. for 'git status',
#                  which returns 1 when there are uncommitted changes
# * Per-INI file .history files
#
# Maybe
# * Fix remote aliases
# * Project groups
# * Intelligent command substring stuff
# * Call git via Python interface
# * Clean up terminal colouring
#   - Factor into separate module
#   - Nicer syntax, allowing something like
#     sys.stdout << Color('foo', RED) << Color('bar', YELLOW) << 'yah\n'
# * Introduce 'SyncProject' as base for UnisonProject
#   - Abstracts sync mechanisms for which push/pull distinction does not make
#     sense.
#


#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

from __future__ import print_function

try:
    import configparser
except ImportError:
    import ConfigParser as configparser

import copy
from datetime import timedelta
from optparse import OptionParser
import os.path
import os
import socket
import subprocess
import sys
from time import time

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
from metasystem import console
from metasystem.console import Color


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

class Verbosity:
    Silent = 0
    Normal = 1
    Loud = 2

YellowThreshold = 60 * 60 * 24 * 7
RedThreshold = YellowThreshold * 2

LeftColumnWidth = 30
Indent = 4

REQUIRED_VARS = ['METASYSTEM_CORE_CONFIG']


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def check_env():
    for var in REQUIRED_VARS:
        value = os.environ.get(var)
        if value == None or value == '':
            raise IOError("Environment variable '{0:s}' not set".format(var))


def PrintToConsole(message, color = None):
    #print "PRINT [%s] color %s" % (message, str(color))
    sys.stdout.state.push()
    sys.stdout.state.set_fg(color)
    sys.stdout.write(message)
    sys.stdout.state.pop()


def PrintError(message):
    PrintToConsole('Error: ' + message + '\n')


def PrintWarning(message):
    PrintToConsole('Warning: ' + message + '\n')


def Execute(command, options, flag = True):
    if Verbosity.Silent != options.verbosity:
        print('\n' + command)
    success = True
    if flag:
        try:
            r = subprocess.call(command.split())
            if 0 != r:
                PrintError("'" + command + "' failed with error " + str(r))
                success = False
        except OSError as e:
            PrintError("'" + command + "' failed:")
            PrintError(str(e))
    return success


def FormatDuration(deltaSecs):
    if deltaSecs < 0:
        return "???"
    delta = timedelta(seconds = deltaSecs)
    value = 0
    unit = ''
    if delta.days >= 7:
        value = delta.days / 7
        unit = 'week'
    else:
        if delta.days > 0:
            value = delta.days
            unit = 'day'
        else:
            if delta.seconds >= 60 * 60:
                value = delta.seconds / (60 * 60)
                unit = 'hour'
            else:
                if delta.seconds >= 60:
                    value = delta.seconds / 60
                    unit = 'min'
                else:
                    value = delta.seconds
                    unit = 'sec'
    result = str(value) + ' ' + unit
    if value > 1:
        result += 's'
    return result


def PrintDuration(now, then):
    if then:
        deltaSecs = now - then
        color = Color.WHITE
        if deltaSecs >= RedThreshold:
            color = Color.RED
        else:
            if deltaSecs >= YellowThreshold:
                color = Color.YELLOW
        PrintToConsole(FormatDuration(deltaSecs), color)
    else:
        sys.stdout.write('never')


# From http://codeliberates.blogspot.com/2008/05/detecting-cpuscores-in-python.html
def NumberOfCores():
    # Linux, Unix and MacOS:
    if hasattr(os, "sysconf"):
        if os.sysconf_names.has_key("SC_NPROCESSORS_ONLN"):
            # Linux & Unix:
            ncpus = os.sysconf("SC_NPROCESSORS_ONLN")
            if isinstance(ncpus, int) and ncpus > 0:
                return ncpus
        else: # OSX:
            return int(os.popen2("sysctl -n hw.ncpu")[1].read())
    # Windows:
    if os.environ.has_key("NUMBER_OF_PROCESSORS"):
        ncpus = int(os.environ["NUMBER_OF_PROCESSORS"]);
        if ncpus > 0:
            return ncpus
    return 1 # Default


class DurationTimer:
    def __init__(self, operation):
        self.operation = operation
        self.start = time()

    def __repr__(self):
        return "\n" + self.operation + " completed in " + FormatDuration(time() - self.start)


def FormatKeyValue(key, value, indent=0):
    num_dots = LeftColumnWidth - (len(key) + 2) - indent
    return (' ' * indent) + key + ' ' + ('.' * num_dots) + ' ' + value



#------------------------------------------------------------------------------
# Local
#------------------------------------------------------------------------------

class Local:
    def __init__(self, name, root, projects):
        self.name = name
        self.root = root
        self.projects = projects

    def __repr__(self):
        repr = FormatKeyValue('name', self.name)
        repr += "\n" + FormatKeyValue('root', self.root)
        projects = ''
        if self.projects:
            projects = self.projects
        repr += "\n" + FormatKeyValue('projects', projects)
        return repr


#------------------------------------------------------------------------------
# Remote
#------------------------------------------------------------------------------

class Remote:
    def __init__(self, name, root, scm_bare):
        self.name = name
        self.root = root
        self.scm_bare = scm_bare

    def __repr__(self):
        repr = "" + self.name
        repr += "\n" + FormatKeyValue('root', self.root, Indent)
        repr += "\n" + FormatKeyValue('scm_bare', str(self.scm_bare), Indent)
        return repr



#------------------------------------------------------------------------------
# History
#------------------------------------------------------------------------------

class History:
    def __init__(self, config):
        self.lastRun = 0
        self.lastSuccessfulRun = 0
        self.config = config
        self.projects = []

    def setLastRun(self, time, success):
        self.lastRun = time
        if success:
            self.lastSuccessfulRun = time

    def setProjectLastRun(self, projectName, time, success, operation = None):
        def _doSetProjectLastRun(project, time, success, operation):
            if 'pull' == operation:
                project.lastPull = time
                if success:
                    project.lastSuccessfulPull = time
            if 'push' == operation:
                project.lastPush = time
                if success:
                    project.lastSuccessfulPush = time
        project = self._project(projectName, True)
        if operation:
            _doSetProjectLastRun(project, time, success, operation)
        else:
            _doSetProjectLastRun(project, time, success, 'pull')
            _doSetProjectLastRun(project, time, success, 'push')

    def read(self, file):
        lines = file.readlines()
        for line in lines:
            line = line.strip()
            if len(line) and not line.startswith('#'):
                tokens = line.split()
                name = tokens.pop(0)
                if 'sync' == name:
                    self.lastRun = int(tokens[0])
                    self.lastSuccessfulRun = int(tokens[1])
                else:
                    self.projects.append(ProjectHistory(name, \
                                         int(tokens[0]), int(tokens[1]), \
                                         int(tokens[2]), int(tokens[3]) ) )
        return

    def write(self, file):
        file.write('sync ' + str.join(' ', [str(self.lastRun), \
                                            str(self.lastSuccessfulRun)] ) \
                   + '\n')
        for project in self.projects:
            file.write(str.join(' ', [project.name, \
                                     str(project.lastPush), \
                                     str(project.lastSuccessfulPush),
                                     str(project.lastPull),
                                     str(project.lastSuccessfulPull)] ) \
                       + '\n')
        return

    def _project(self, name, create = False):
        result = None
        for project in self.projects:
            if name == project.name:
                result = project
        if not result and create:
            result = ProjectHistory(name)
            self.projects.append(result)
        return result

    def printToConsole(self):
        now = int(time())
        sys.stdout.write('Last run:                 ')
        PrintDuration(now, self.lastRun)
        sys.stdout.write('\n')
        color = Color.WHITE
        if self.lastSuccessfulRun != self.lastRun:
            color = Color.YELLOW
        PrintToConsole('Last successful run:      ', color)
        PrintDuration(now, self.lastSuccessfulRun)
        sys.stdout.write('\n')
        for name in self.config['projects'].keys():
            project = self.config['projects'][name]
            history = self._project(name)
            print()
            project.printHistory(history, now)


#------------------------------------------------------------------------------
# ProjectHistory
#------------------------------------------------------------------------------

class ProjectHistory:
    def __init__(self, name, lastPull = 0, lastSuccessfulPull = 0, \
                 lastPush = 0, lastSuccessfulPush = 0):
        self.name = name
        self.lastPull = lastPull
        self.lastSuccessfulPull = lastSuccessfulPull
        self.lastPush = lastPush
        self.lastSuccessfulPush = lastSuccessfulPush



#------------------------------------------------------------------------------
# ProjectGroup
#------------------------------------------------------------------------------

class ProjectGroup:
    def __init__(self, name):
        self.name = name
        self.projects = []

    def __repr__(self):
        repr = FormatKeyValue('name', self.name)
        repr += "\n" + FormatKeyValue('projects', ' '.join(self.projects))
        return repr



#------------------------------------------------------------------------------
# Project
#------------------------------------------------------------------------------

class Project:
    def __init__(self, name, auto, direction, local, local_path, default_remote, remote_path):
        self.name = name
        self.auto = auto
        if direction and direction != 'push' and direction != 'pull':
            raise IOError("Direction '" + direction + \
                           "' in project '" + name + " is invalid")
        self.direction = direction
        self.local = local
        self.local_path = local_path
        self.default_remote = default_remote
        self.remote_path = remote_path
        self.type = 'unknown'

    def __repr__(self):
        return self.getFormat()

    def getFormat(self, remote=None):
        repr = "" + self.name
        repr += "\n" + FormatKeyValue('type', self.type, Indent)
        repr += "\n" + FormatKeyValue('auto', str(self.auto), Indent)
        repr += "\n" + FormatKeyValue('local path', self.local_path, Indent)
        if remote:
            repr += "\n" + FormatKeyValue('remote', remote.name, Indent)
            repr += "\n" + FormatKeyValue('remote root', remote.root, Indent)
        else:
            repr += "\n" + FormatKeyValue('default remote', self.default_remote.name, Indent)
        repr += "\n" + FormatKeyValue('remote path', self.remote_path, Indent)
        direction = 'both'
        if self.direction:
            direction = self.direction
        repr += "\n" + FormatKeyValue('direction', direction, Indent)
        if remote:
            repr += "\n" + FormatKeyValue('full local path', self.fullLocalPath(), Indent)
            repr += "\n" + FormatKeyValue('full remote path', remote.root + '/' + self.remote_path, Indent)
        return repr

    def init(self, history, options, config):
        remote = self.getRemote(options, config)
        now = int(time())
        if not options.dry_run:
            os.makedirs(self.fullLocalPath())
        success = self._init(remote, options)
        history.setProjectLastRun(self.name, now, success)
        return success

    def getRemote(self, options, config):
        remote = self.default_remote
        if options.remote:
            remote = config['remotes'][options.remote]
        return remote

    def fullLocalPath(self):
        return os.path.join(self.local.root, self.local_path)

    def printHistory(self, history, now):
        print(self.name + ' [' + self.type + ']: ')
        if history:
            self._printHistory(history, now)
        else:
            print('    Never synchronised')

    def _printHistory(self, history, now):
        sys.stdout.write('    Last pull:            ')
        PrintDuration(now, history.lastPull)
        sys.stdout.write('\n')
        color = Color.WHITE
        if history.lastSuccessfulPull != history.lastPull:
            color = Color.YELLOW
        PrintToConsole('    Last successful pull: ', color)
        PrintDuration(now, history.lastSuccessfulPull)
        sys.stdout.write('\n')
        sys.stdout.write('    Last push:            ')
        PrintDuration(now, history.lastPush)
        sys.stdout.write('\n')
        color = Color.WHITE
        if history.lastSuccessfulPush != history.lastPush:
            color = Color.YELLOW
        PrintToConsole('    Last successful push: ', color)
        PrintDuration(now, history.lastSuccessfulPush)
        sys.stdout.write('\n')


#------------------------------------------------------------------------------
# ScmProject
#------------------------------------------------------------------------------

class ScmProject(Project):
    def __init__(self, name, auto, direction, local, local_path, default_remote, remote_path, branches):
        Project.__init__(self, name, auto, direction, local, local_path, default_remote, remote_path)
        self.branches = branches

    def getFormat(self, remote=None):
        repr = Project.getFormat(self, remote)
        branches = 'all'
        if self.branches:
            branches = self.branches
        repr += "\n" + FormatKeyValue('branches', branches, Indent)
        return repr

    def sync(self, history, options, subdir):
        if '' != subdir:
            PrintWarning("subdir '" + subdir + "' is ignored for " \
                         + self.type + " project '" + self.name + "'")

        direction = self.direction
        if options.direction:
            direction = options.direction

        operations = []
        if direction:
            operations.append(direction)
        else:
            operations.append('pull')
            operations.append('push')

        if not options.quiet:
            print("\nChanging directory to " + self.fullLocalPath() + " ...")
            os.chdir(self.fullLocalPath())

        overallSuccess = True
        for operation in operations:
            now = int(time())
            success = True
            if not self.branches:
                success = self._sync(operation, '', options)
            else:
                branchList = self.branches.split()
                for branch in branchList:
                    success &= self._sync(operation, ' ' + branch, options)
            if not options.dry_run:
                history.setProjectLastRun(self.name, now, success, operation)
            overallSuccess &= success
        return overallSuccess


#------------------------------------------------------------------------------
# GitProject
#------------------------------------------------------------------------------

class GitProject(ScmProject):
    def __init__(self, name, auto, direction, local, local_path, default_remote, remote_path, branches):
        ScmProject.__init__(self, name, auto, direction, local, local_path, default_remote, remote_path, branches)
        self.type = 'git'

    def getFormat(self, remote=None):
        repr = ScmProject.getFormat(self, remote)
        return repr

    def _remote_path(self, remote, options):
        remote_path = remote.root + '/' + self.remote_path
        if (remote.scm_bare):
            remote_path += '.git'
        return remote_path

    def _init(self, remote, options):
        remote_path = self._remote_path(remote, options)
        command = 'git clone ' + remote_path + ' ' + self.fullLocalPath()
        return Execute(command, options, (not options.dry_run))

    def _sync(self, operation, branch, options):
        verbosity = ''
        if Verbosity.Loud == options.verbosity:
            verbosity = ' --verbose'
        remote_path = ''
        if operation == 'push' and branch != '':
            remote = self.getRemote(options, config)
            remote_path = self._remote_path(remote, options)
        command = 'git ' + operation + ' ' + remote_path + ' ' + branch + verbosity
        execute = True
        if options.dry_run == 1:
            command += ' --dry-run'
        if options.dry_run > 1:
            execute = False
        return Execute(command, options, execute)

    def status(self, options):
        command = ''
        if options.verbose:
            command = 'git diff'
        else:
            command = 'git status'
        if not options.quiet:
            print("Changing directory to " + self.fullLocalPath() + " ...")
            os.chdir(self.fullLocalPath())
            Execute(command, options)
        # 'git status' returns 1 if there are uncommitted changes
        return True


#------------------------------------------------------------------------------
# HgProject
#------------------------------------------------------------------------------

class HgProject(ScmProject):
    def __init__(self, name, auto, direction, local, local_path, default_remote, remote_path, branches):
        ScmProject.__init__(self, name, auto, direction, local, local_path, default_remote, remote_path, branches)
        self.type = 'hg'

    def getFormat(self, remote=None):
        repr = ScmProject.getFormat(self, remote)
        return repr

    def _init(self, remote, options):
        remote_path = remote.root + '/' + self.remote_path
        if (remote.scm_bare):
            remote_path += '.hg'
        command = 'hg clone ' + remote_path + ' ' + self.fullLocalPath()
        return Execute(command, options, (not options.dry_run))

    def _sync(self, operation, branch, options):
        command = 'hg ' + operation
        return Execute(command, options, (not options.dry_run))
        return True

    def status(self, options):
        return True


#------------------------------------------------------------------------------
# UnisonProject
#------------------------------------------------------------------------------

class UnisonProject(Project):
    def __init__(self, name, auto, direction, prefer, local, local_path, default_remote, remote_path, subdirs):
        Project.__init__(self, name, auto, direction, local, local_path, default_remote, remote_path)
        self.type = 'unison'
        self.subdirs = subdirs
        self.prefer = prefer

    VerbosityMap = {
        Verbosity.Silent : '-silent ',
        Verbosity.Normal : '',
        Verbosity.Loud   : ''
    }

    def getFormat(self, remote=None):
        repr = Project.getFormat(self, remote)
        subdirs = '*'
        if self.subdirs:
            subdirs = self.subdirs
        repr += "\n" + FormatKeyValue('subdirs', subdirs, Indent)
        return repr

    def _generateProfile(self, remote):
        unisonProfilePath = os.path.join(os.environ.get('HOME'), '.unison')
        if not os.path.exists(unisonProfilePath):
            os.makedirs(unisonProfilePath)
        commonProfilePath = os.path.join(unisonProfilePath, 'common.prf')
        profileName = '_sync_' + self.name + '.prf'
        profilePath = os.path.join(unisonProfilePath, profileName)
        commonProfile = open(commonProfilePath, 'w')
        commonProfile.write('ignore = Name *~\n')
        commonProfile.write('ignore = Name .*.swp\n')
        commonProfile.write('fastcheck = true\n')
        commonProfile.write('perms = 0\n')
        maxthreads = NumberOfCores() / 2
        if maxthreads < 1:
            maxthreads = 1
        commonProfile.write('maxthreads = ' + str(maxthreads) + '\n')
        profile = open(profilePath, 'w')
        profile.write('include common.prf\n')
        profile.write('root = ' + self.fullLocalPath() + '\n')
        profile.write('root = ' + remote.root + '/' + self.remote_path + '\n')
        if self.prefer == 'local':
            profile.write('prefer = ' + self.fullLocalPath() + '\n')
        if self.prefer == 'remote':
            profile.write('prefer = ' + os.path.join(remote.root, self.remote_path) + '\n')
        return profileName

    def _init(self, remote, options):
        return self._sync(remote, options)

    def sync(self, history, options, subdir):
        now = int(time())
        remote = self.getRemote(options, config)
        success = self._sync(remote, options, subdir)
        if not options.dry_run:
            history.setProjectLastRun(self.name, now, success)
        return success

    def _sync(self, remote, options, subdir = ''):
        try:
            profile = self._generateProfile(remote)
        except Exception as e:
            print(e)
            return False

        success = True
        command = 'unison -auto -ui text '
        command += self.VerbosityMap[options.verbosity]
        if '' != subdir:
            command += '-path ' + subdir + ' '
        else:
            if self.subdirs:
                subdirList = self.subdirs.split()
                for subdir in subdirList:
                    command += '-path ' + subdir + ' '
        command += profile
        if options.dry_run == 1:
            # Unison has no -dry-run option, so we resort to nastiness...
            # Run without -batch, and send 'q' when asked whether to
            # proceed
            print('\n' + command)
            process = subprocess.Popen(command.split(),
                                       shell=True,
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT,
                                       stdin=subprocess.PIPE)
            output = ''
            while (True):
                buf = process.stdout.read(1)
                if len(buf) == 0:
                    break
                output += buf
                sys.stdout.write(buf)
                if 'Proceed with propagating updates? [] ' in output:
                    process.stdin.write('q\n')
                    break
        else:
            if options.dry_run == 0:
                command += " -batch"
            success = Execute(command, options)
        return success

    def status(self, options):
        return True

    def _printHistory(self, history, now):
        sys.stdout.write('    Last sync:            ')
        PrintDuration(now, history.lastPull)
        sys.stdout.write('\n')
        color = Color.WHITE
        if history.lastSuccessfulPull != history.lastPull:
            color = Color.YELLOW
        PrintToConsole('    Last successful sync: ', color)
        PrintDuration(now, history.lastSuccessfulPull)
        sys.stdout.write('\n')


#------------------------------------------------------------------------------
# RsyncProject
#------------------------------------------------------------------------------

class RsyncProject(Project):
    def __init__(self, name, auto, direction, local, local_path, default_remote,
                 remote_path, rsync_options):
        Project.__init__(self, name, auto, direction, local, local_path, default_remote, remote_path)
        self.type = 'rsync'
        self.rsync_options = rsync_options

    def _init(self, remote, options):
        return self._sync(remote, options)

    def getFormat(self, remote=None):
        repr = Project.getFormat(self, remote)
        rsync_options = ''
        if self.rsync_options:
            rsync_options = self.rsync_options
        repr += "\n" + FormatKeyValue('rsync_options', rsync_options, Indent)
        return repr

    def sync(self, history, options, subdir):
        now = int(time())
        remote = self.getRemote(options, config)
        success = self._sync(remote, options, subdir)
        if not options.dry_run:
            history.setProjectLastRun(self.name, now, success)
        return success

    def _pull(self, remote, options, subdir):
        command = 'rsync -azvvrl '
        if self.rsync_options:
            command = command + self.rsync_options
        command = command + ' -e ssh ' +\
                  remote.root + ':' + self.remote_path +\
                  " " + self.local_path
        execute = True
        if options.dry_run == 1:
            command += " --dry-run"
        if options.dry_run > 1:
            execute = False
        return Execute(command, options, execute)

    def _push(self, remote, options, subdir):
        print("\nChanging directory to " + self.fullLocalPath() + " ...")
        os.chdir(self.fullLocalPath())
        command = 'rsync -azvvrl '
        if self.rsync_options:
            command = command + self.rsync_options
        command = command + ' -e ssh . ' + remote.root + ':' + self.remote_path
        execute = True
        if options.dry_run == 1:
            command += " --dry-run"
        if options.dry_run > 1:
            execute = False
        return Execute(command, options, execute)

    def _sync(self, remote, options, subdir = ''):
        result = True
        if self.direction != 'pull':
            result = self._push(remote, options, subdir)
        if result and self.direction != 'push':
            result = self._pull(remote, options, subdir)
        return result

    def status(self, options):
        return True


#------------------------------------------------------------------------------
# Subroutines
#------------------------------------------------------------------------------

def process_kwargs(defaults, kwargs):
    diff = set(kwargs.keys()) - set(defaults.keys())
    if diff:
        raise TypeError('Error: invalid arguments: %s' % list(diff))
    defaults.update(kwargs)
    return defaults


def ExtractRequiredIniField(parser, section, field, **kwargs):
    kwargs = process_kwargs(dict(local=None), kwargs)
    result = None
    local_field = None
    if kwargs['local']:
        local_field = field + '(' + kwargs['local'] + ')'
        if parser.has_option(section, local_field):
            result = parser.get(section, local_field)
    if not result:
        result = parser.get(section, field)
    if not result:
        msg = "Required field '" + field + "' in section '" \
              + section + "' not found in config file"
        raise IOError(msg)
    return result


def ExtractOptionalIniField(parser, section, field, **kwargs):
    kwargs = process_kwargs(dict(local=None), kwargs)
    result = None
    local_field = None
    if kwargs['local']:
        local_field = field + '(' + kwargs['local'] + ')'
        if parser.has_option(section, local_field):
            result = parser.get(section, local_field)
    if not result:
        if parser.has_option(section, field):
            result = parser.get(section, field)
    return result


def ExtractOptionalIniFieldBool(parser, section, field, **kwargs):
    kwargs = process_kwargs(dict(local=None, default=False), kwargs)
    result = kwargs['default']
    value = ExtractOptionalIniField(parser, section, field, local=kwargs['local'])
    valueDict = {
        'true' : True,
        'false' : False
    }
    if value:
        result = valueDict[value]
    return result


def ParseIniFile(fileName):
    config = { }

    parser = configparser.RawConfigParser()
    if len(parser.read(fileName)) == 0:
        raise IOError("Failed to read config file " + fileName)

    ParseLocal(parser, config)
    ParseRemotes(parser, config)

    projects = []
    if config['local'].projects:
        projects = config['local'].projects.split()
    else:
        for section in parser.sections():
            if section.startswith('project:'):
                projects.append(section[8:])

    ParseProjects(parser, projects, config)

    ParseProjectGroups(parser, config)

    return config


def ParseLocal(parser, config):
    config['hostname'] = socket.gethostname()
    for section in parser.sections():
        if section.startswith('local:'):
            name = section[6:]
            hostname = ExtractRequiredIniField(parser, section, 'hostname')
            root = ExtractRequiredIniField(parser, section, 'root')
            projects = ExtractOptionalIniField(parser, section, 'projects')
            if hostname == config['hostname']:
                config['local'] = Local(name, root, projects)
    if not config.get('local'):
        raise IOError("No local definition found for hostname '" + \
                       config['hostname'] + "'")


def ParseRemotes(parser, config):
    config['remotes'] = { }
    for section in parser.sections():
        if section.startswith('remote:'):
            name = section[7:]
            host_root = 'root(' + config['local'].name + ')'
            root = ExtractOptionalIniField(parser, section, 'root', local=config['local'].name)
            if not root:
                raise IOError("Remote '" + name + "' has neither 'root' nor '" \
                               + host_root + "' property")
            scm_bare = ExtractOptionalIniFieldBool(parser, section, 'scm_bare', default=True)
            config['remotes'][name] = Remote(name, root, scm_bare)
        if section.startswith('remote-alias:'):
            name = section[13:]
            target = ExtractRequiredIniField(parser, section, 'target', local=config['local'].name)
            # This is a bit of a nasty hack...
            # We should really use encapsulation on the config object, and have
            # a getRemote(name) function which is alias-aware
            remote = copy.deepcopy(config['remotes'][target])
            remote.name = name
            config['remotes'][name] = remote


def ParseProjects(parser, names, config):
    config['projects'] = { }
    for name in names:
        section = 'project:' + name
        type = ExtractRequiredIniField(parser, section, 'type')
        auto = ExtractOptionalIniFieldBool(parser, section, 'auto', default=True)
        dispatch = {
                        'git':        CreateGitProject
                   ,    'hg':         CreateHgProject
                   ,    'rsync':      CreateRsyncProject
                   ,    'unison':     CreateUnisonProject
                   }
        config['projects'][name] = dispatch.get(type, InvalidProjectType)(parser, name, auto, config)


def ParseProjectGroups(parser, config):
    config['project-groups'] = { }
    for section in parser.sections():
        if section.startswith('project-group:'):
            name = section[14:]
            if name in config['projects'].keys():
                raise IOError("Name '" + name + "' refers to both a project and a project-group")
            project_list = ExtractRequiredIniField(parser, section, 'projects', local=config['local'].name)
            group = ProjectGroup(name)
            group.projects = project_list.split()
            config['project-groups'][name] = group


def OpenHistoryFile(mode):
    filename = os.path.join(os.environ.get('HOME'), '.sync-history')
    file = None
    try:
        file = open(filename, mode)
    finally:
        return file


def ReadHistory(config):
    file = OpenHistoryFile('r')
    history = History(config)
    if file:
        history.read(file)
    return history


def WriteHistory(history):
    success = False
    file = OpenHistoryFile('w')
    if file:
        history.write(file)
        success = True
    else:
        PrintError("Writing history file failed")
    return success


def CreateGitProject(parser, name, auto, config):
    section = 'project:' + name
    local = config['local']
    local_path = ExtractRequiredIniField(parser, section, 'local_path', local=local.name)
    default_remote_name = ExtractRequiredIniField(parser, section, 'default_remote', local=local.name)
    default_remote = config['remotes'][default_remote_name]
    remote_path = ExtractRequiredIniField(parser, section, 'remote_path', local=local.name)
    branches = ExtractOptionalIniField(parser, section, 'branches', local=local.name)
    direction = ExtractOptionalIniField(parser, section, 'direction', local=local.name)
    return GitProject(name, auto, direction, local, local_path, default_remote, remote_path, branches)


def CreateHgProject(parser, name, auto, config):
    section = 'project:' + name
    local = config['local']
    local_path = ExtractRequiredIniField(parser, section, 'local_path', local=local.name)
    default_remote_name = ExtractRequiredIniField(parser, section, 'default_remote', local=local.name)
    rdefault_emote = config['remotes'][default_remote_name]
    remote_path = ExtractRequiredIniField(parser, section, 'remote_path', local=local.name)
    branches = ExtractOptionalIniField(parser, section, 'branches', local=local.name)
    direction = ExtractOptionalIniField(parser, section, 'direction', local=local.name)
    return HgProject(name, auto, direction, local, local_path, default_remote, remote_path, branches)


def CreateRsyncProject(parser, name, auto, config):
    section = 'project:' + name
    local = config['local']
    local_path = ExtractRequiredIniField(parser, section, 'local_path', local=local.name)
    default_remote_name = ExtractRequiredIniField(parser, section, 'default_remote', local=local.name)
    default_remote = config['remotes'][default_remote_name]
    remote_path = ExtractRequiredIniField(parser, section, 'remote_path', local=local.name)
    direction = ExtractOptionalIniField(parser, section, 'direction', local=local.name)
    rsync_options = ExtractOptionalIniField(parser, section, 'rsync_options', local=local.name)
    return RsyncProject(name, auto, direction, local,local_path, default_remote, remote_path, rsync_options)


def CreateUnisonProject(parser, name, auto, config):
    section = 'project:' + name
    local = config['local']
    local_path = ExtractRequiredIniField(parser, section, 'local_path', local=local.name)
    default_remote_name = ExtractRequiredIniField(parser, section, 'default_remote', local=local.name)
    default_remote = config['remotes'][default_remote_name]
    remote_path = ExtractRequiredIniField(parser, section, 'remote_path', local=local.name)
    direction = ExtractOptionalIniField(parser, section, 'direction', local=local.name)
    subdirs = ExtractOptionalIniField(parser, section, 'subdirs', local=local.name)
    # TODO: extract 'prefer' from config file or command line
    prefer = None
    return UnisonProject(name, auto, direction, prefer, local,local_path, default_remote, remote_path, subdirs)


def InvalidProjectType(parser, name, auto, config):
    section = 'project:' + name
    local = config['local']
    type = ExtractRequiredIniField(parser, section, 'type', local=local.name)
    raise IOError("Project type '" + type + "' for project '" + name \
                   + "' is not supported")


def CreateCommandLineParser():
    parser = OptionParser()
    usage = sys.argv[0] + " command [args] [options]"
    usage += "\n\nCommands:"
    usage += "\n  init [projects ...]       Initialize local copies of projects"
    usage += "\n  list                      List contents of INI file"
    usage += "\n  status [projects ...]     Get current project status"
    usage += "\n  history [projects ...]    Get time and outcome of previous syncs"
    usage += "\n  sync [projects ...]       Perform synchronisation"
    parser.set_usage(usage)
    parser.add_option('-i', '--ini', type='string', dest='ini_filename',
                      help='INI file name')
    parser.add_option('-d', '--direction', dest='direction',
                      choices=['push', 'pull', 'both'],
                      help='Direction(s) of the synchronisation operation (push|pull|both)')
    parser.add_option('-v', '--verbose', dest='verbose', action='store_true',
                      default=False, help='Verbose output')
    parser.add_option('-q', '--quiet', dest='quiet', action='store_true',
                      default=False, help='No output')
    parser.add_option('-n', '--dry-run', dest='dry_run', action='count',
                      default=0, help='Do not actually execute any actions')
    parser.add_option('-a', '--all', dest='all', action='store_true',
              default=False, help='Sync all projects, including those with auto=false')
    parser.add_option('-r', '--remote', dest='remote',
                      help="Name of remote")
    parser.add_option('-p', '--prefer', dest='prefer',
                      help="Which copy to prefer in case of conflict (local|remote)")

    return parser


def ProcessCommandLine():
    parser = CreateCommandLineParser()
    (options, args) = parser.parse_args()
    result = { }
    result['options'] = options
    result['args'] = args

    options.verbosity = Verbosity.Normal
    if options.verbose:
        options.verbosity = Verbosity.Loud
    else:
        if options.quiet:
            options.verbosity = Verbosity.Silent

    if None == result['options'].ini_filename:
        result['options'].ini_filename = os.path.join(os.environ.get('METASYSTEM_CORE_CONFIG'), 'sync.ini')

    return result


def InvalidAction(commandLine, config):
    parser = CreateCommandLineParser()
    PrintError("Invalid action '" + commandLine['command'] + "'")
    parser.print_help()
    exit(1)


def GetProjects(action, args, config):
    result = config['projects'].keys()
    if len(args):
        if action == args[0]:
            args.pop(0)
    if len(args):
        result = []
        for entry in args:
            project = entry
            index = project.find('/')
            if -1 != index:
                project = project[0:index]
            if project in config['projects'].keys():
                result.append(entry)
            elif project in config['project-groups'].keys():
                result += config['project-groups'][entry].projects
            else:
                raise IOError("'" + entry + "' does not refer to a project or project group")
    return result


#------------------------------------------------------------------------------
# Action implementations
# None of these should throw an exception; each one must return True or False
# to indicate overall success
#------------------------------------------------------------------------------

def ActionList(commandLine, config):
    commandLine['args'].pop(0)
    ruler = '-----------------------------------------------------------------------'
    print()
    print("INI filename:     " + commandLine['options'].ini_filename)
    print()
    print(ruler)
    print("Local")
    print(ruler)
    print()
    print(FormatKeyValue('hostname', config['hostname']))
    print(config['local'])
    print()
    print(ruler)
    print("Remotes")
    print(ruler)
    for name in config['remotes'].keys():
        print("\n", config['remotes'][name])
    print()
    print(ruler)
    print("Projects")
    print(ruler)
    for name in config['projects'].keys():
        print("\n", config['projects'][name])
    print()
    print(ruler)
    print("Project groups")
    print(ruler)
    for name in config['project-groups'].keys():
        print("\n", config['project-groups'][name])



# Helper for ActionInit, ActionSync
def PrintResults(timer, result):
    PrintToConsole(timer.__repr__() + '\n\n', Color.CYAN)

    if len(result.keys()):
        nameWidth = max([len(x) for x in result.keys()])
        for name in result.keys():
            formatString = "%(name)-" + str(nameWidth) + "s : "
            sys.stdout.write(formatString % {'name' : name})
            if result[name]:
                PrintToConsole('OK', Color.GREEN)
            else:
                PrintToConsole('FAILED', Color.RED)
            sys.stdout.write('\n')

def printLocal(config):
    PrintToConsole("Local\n\n", Color.GREEN)
    print(config['local'])


def printProject(project, options, config):
    remote = project.getRemote(options, config)
    print(project.getFormat(remote))


def ActionInit(commandLine, config):
    history = ReadHistory(config)
    now = int(time())
    options = commandLine['options']

    projectNames = GetProjects('init', commandLine['args'], config)

    overallTimer = DurationTimer('Sync')
    result = {}
    printLocal(config)

    success = True
    for name in projectNames:
        project = config['projects'][name]
        if os.path.exists(project.local_path):
            PrintToConsole("\nSkipping project '" + project.name + "' [" + project.type + "]\n", \
               Color.CYAN)
            print("Local path '" + project.local_path + "' already exists")
        else:
            PrintToConsole("\nInitialising project '" + project.name + "' [" + project.type + "] ...\n\n", \
                           Color.GREEN)
            printProject(project, options, config)
            try:
                timer = DurationTimer("Initialization of project '" + name + "'")
                projectSuccess = project.init(history, options, config)
                result[name] = projectSuccess
                success &= projectSuccess
                print(timer)
            except Exception as e:
                print(e)
                result[name] = False
                success = False

    history.setLastRun(now, success)
    success &= WriteHistory(history)
    PrintResults(overallTimer, result)
    return success


def ActionSync(commandLine, config):
    history = ReadHistory(config)
    now = int(time())
    options = commandLine['options']

    projectNames = GetProjects('sync', commandLine['args'], config)

    overallTimer = DurationTimer('Sync')
    result = {}
    printLocal(config)

    success = True
    for value in projectNames:
        name = value
        subdir = ''
        index = value.find('/')
        if -1 != index:
            name = value[0:index]
            subdir = value[index+1:]
        project = config['projects'][name]
        if len(commandLine['args']) or project.auto or commandLine['options'].all:
            PrintToConsole("\nSynchronising project '" + name + "' [" + project.type + "] ...\n\n", \
                           Color.GREEN)
            printProject(project, options, config)
            try:
                timer = DurationTimer("Sync of project '" + name + "'")
                projectSuccess = project.sync(history, options, subdir)
                result[name] = projectSuccess
                success &= projectSuccess
                print(timer)
            except Exception as e:
                print(e)
                result[name] = False
                success = False
        else:
            PrintToConsole("\nSkipping project '" + name + "' [" + project.type + "] - auto flag not set\n", \
               Color.CYAN)

    history.setLastRun(now, success)
    success &= WriteHistory(history)
    PrintResults(overallTimer, result)
    return success


def ActionStatus(commandLine, config):
    projectNames = GetProjects('status', commandLine['args'], config)

    success = True
    for name in projectNames:
        project = config['projects'][name]
        if not commandLine['options'].quiet:
            print("\nStatus of project '" + name + "' [" + project.type + "] ...")
        success &= project.status(commandLine['options'])
    return success


def ActionHistory(commandLine, config):
    commandLine['args'].pop(0)
    history = ReadHistory(config)
    history.printToConsole()
    return True


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_env()

commandLine = ProcessCommandLine()
config = ParseIniFile(commandLine['options'].ini_filename)

commandLine['command'] = 'sync'

if len(commandLine['args']):
    commandLine['command'] = commandLine['args'][0]

dispatch = {
                'init':     ActionInit
           ,    'list':     ActionList
           ,    'sync':     ActionSync
           ,    'status':   ActionStatus
           ,    'history':  ActionHistory
           }

success = dispatch.get(commandLine['command'], ActionSync)(commandLine, config)

exitCode = 0
if not success:
    exitCode = 1
exit(exitCode)

