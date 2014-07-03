#!/usr/bin/env python

#------------------------------------------------------------------------------
# TODO
#------------------------------------------------------------------------------

# Definitely:
# * Implement ActionUnzip

# Maybe
# * Add a dictionary containing exclusion patterns for unzip
# * Calculate transfer speed after each copy is complete


#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

import ConfigParser
from datetime import timedelta
from optparse import OptionParser, OptionGroup
import os.path
import os
import re
import shutil
import subprocess
import sys
from time import time

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
import Console


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

class Verbosity:
    Silent = 0
    Normal = 1
    Loud = 2

REQUIRED_VARS = ['METASYSTEM_CONFIG']

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def check_env():
    for var in REQUIRED_VARS:
        value = os.environ.get(var)
        if value == None or value == '':
            raise IOError("Environment variable '{0:s}' not set".format(var))

def PrintToConsole(message, color = None):
    Console.stdout.set_fg(color)
    Console.stdout.write(message)

def PrintError(message):
    PrintToConsole('Error: ' + message + '\n', Console.RED)

def UsageError(error):
    parser = CreateCommandLineParser()
    PrintError(error)
    parser.print_help()
    exit(1)

def PrintWarning(message):
    PrintToConsole('Warning: ' + message + '\n', Console.YELLOW)

def Call(command, options):
    print command
    if not options.dry_run:
        ret = subprocess.call(command.split())
        if 0 != ret:
            raise IOError("Command '" + command + "' failed with error " + str(ret))

def Execute(command, options):
    print command
    if not options.dry_run:
        process = subprocess.Popen(command.split(),
                                   shell=True,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
        while (True):
            output = process.stdout.readline()
            if len(output) == 0:
                break
            if options.verbosity != Verbosity.Silent:
                print output
        print "\n"

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


class DurationTimer:
    def __init__(self, operation = ''):
        self.operation = operation
        self.start = time()

    def __repr__(self):
        formatted = FormatDuration(time() - self.start)
        if self.operation == '':
            return formatted
        return "\n" + self.operation + " completed in " + formatted

def ExcludedFrom(all, included):
    excluded = []
    for x in all:
        found = False
        for y in included:
            if x == y:
                found = True
                break
        if not found:
            excluded.append(x)
    return excluded


# File copy with progress bar
# Based on code from http://stackoverflow.com/questions/274493/how-to-copy-a-file-in-python-with-a-progress-bar

class ProgressBar:
    def __init__(self, minValue = 0, maxValue = 10, totalWidth = 12):
        self.min = minValue
        self.max = maxValue
        self.span = maxValue - minValue
        self.width = totalWidth
        self.amount = 0
        self.percentDone = 0
        self.elapsedSecs = 0
        self.startTime = time()
        self.update(0) # Build progress bar string

    def update(self, newAmount = 0):
        if newAmount < self.min: newAmount = self.min
        if newAmount > self.max: newAmount = self.max
        self.amount = newAmount

        # Figure out the new percent done, round to an integer
        diffFromMin = float(self.amount - self.min)
        percentDone = (diffFromMin / float(self.span)) * 100.0
        percentDone = round(percentDone)
        percentDone = int(percentDone)

        # Calculate elapsed time
        secs = int(time() - self.startTime)

        # Decide whether to update the display
        if 100 == self.percentDone:
            return
        if (0 == newAmount) or (percentDone - self.percentDone >= 1) \
            or (secs - self.elapsedSecs >= 1) or (100 == percentDone):
            self.percentDone = percentDone
            self.elapsedSecs = secs
        else:
            return

        # Figure out how many hash bars the percentage should be
        allFull = self.width - 2
        numHashes = (percentDone / 100.0) * allFull
        numHashes = int(round(numHashes))

        # Build progress bar
        output = "[" + '#'*numHashes + ' '*(allFull-numHashes) + "]"

        # Append percentage
        output += ' %3d%%' % percentDone

        # Calculate elapsed time
        mins = 0
        hours = 0
        if secs >= 60 * 60:
            hours = int(secs / (60 * 60))
            secs -= hours * (60 * 60)
        if secs >= 60:
            mins = int(secs / 60)
            secs -= mins * 60
        output += ' %02d:%02d:%02d' % (hours,mins,secs) #hours, mins, secs)

        # Write to display
        sys.stdout.write('\r%s\r' % output)

        if 100 == percentDone:
            sys.stdout.write('\n')


def fileCopy(src, dest, callback = None, block_size = 16384):
    fsrc = None
    fdest = None
    try:
        fsrc = open(src, "rb")
        fdest = open(dest, "wb")
        pos = 0
        while True:
            block = fsrc.read(block_size)
            pos += block_size
            if block:
                fdest.write(block)
                if callback:
                    callback(pos)
            else:
                if callback:
                    callback(pos)
                break
    finally:
        fsrc.close()
        fdest.close()


#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

class Project:
    def __init__(self, name, remote_path, version_dir, zip_prefix):
        self.name = name
        self.remote_path = remote_path
        self.version_dir = version_dir
        self.zip_prefix = zip_prefix

    def __repr__(self):
        repr = self.name + "\n"
        repr += "    Remote path:         " + self.remote_path + "\n"
        repr += "    Version dir pattern: " + self.version_dir + "\n"
        repr += "    Zip filename prefix: " + self.zip_prefix
        return repr

    def remoteVersionDir(self, config, version):
        version_dir = self.version_dir
        version_dir = version_dir.replace('${VERSION}', version)
        result = os.path.join(config['remote_root'], self.remote_path, version_dir)
        return result

    def localVersionDir(self, config, version):
        version_dir = self.version_dir
        version_dir = version_dir.replace('${VERSION}', version)
        result = os.path.join(config['local_root'], self.remote_path, version_dir)
        return result

    def zipFilenamePrefix(self, version):
        return self.zip_prefix.replace('${VERSION}', version)

    def zipFileRegexp(self, version, pattern = '.*'):
        pattern = '^' + self.zipFilenamePrefix(version) + pattern + '\\.zip'
        return re.compile(pattern)

    def zipFileList(self, path, version, verbosity):
        list = []
        if verbosity != Verbosity.Silent:
            print "Retrieving list of zip files from " + path + " ..."
        regexp = self.zipFileRegexp(version)
        for entry in os.listdir(path):
            if regexp.match(entry):
                list.append(entry)
        return list


class Environment:
    def __init__(self, options, config, project, version):
        self.options = options
        self.config = config
        self.project = project
        self.version = version
        self.remote_zip_files = []
        self.local_zip_files = []

    def __repr__(self):
        repr = ''
        repr += "\nProject: " + self.project.__repr__() + "\n"
        repr += "\nVersion: " + self.version
        repr += "\nRemote path: " + self.remoteDir()
        repr += "\nLocal path: " + self.localDir() + "\n"
        return repr

    def localDir(self):
        return self.project.localVersionDir(self.config, self.version)

    def remoteDir(self):
        return self.project.remoteVersionDir(self.config, self.version)

    def remoteZipFileList(self):
        if not len(self.remote_zip_files):
            self.remote_zip_files = self.project.zipFileList(self.remoteDir(), self.version, self.options.verbosity)
        return self.remote_zip_files

    def localZipFileList(self):
        if not len(self.local_zip_files):
            self.local_zip_files = self.project.zipFileList(self.localDir(), self.version, self.options.verbosity)
        return self.local_zip_files

    def _zipFileRegexp(self, pattern):
        return self.project.zipFileRegexp(self.version, pattern)

    def _appendEpoc32(self, regexpList):
        regexpList.append(self._zipFileRegexp('epoc32'))
        regexpList.append(self._zipFileRegexp('epoc32_data.*'))
        regexpList.append(self._zipFileRegexp('epoc32_part.*'))
        regexpList.append(self._zipFileRegexp('epoc32_.*tools'))
        regexpList.append(self._zipFileRegexp('epoc32_gcc.*'))
        regexpList.append(self._zipFileRegexp('epoc32_rom.*'))
        regexpList.append(self._zipFileRegexp('epoc32_s60.*'))
        regexpList.append(self._zipFileRegexp('epoc32_sbs_config'))
        regexpList.append(self._zipFileRegexp('epoc32_stdapis'))
        regexpList.append(self._zipFileRegexp('epoc32_ost_dictionaries'))

    def _filterZipFileList(self, inputList):
        regexpList = []
        if self.options.epoc32_include:
            regexpList.append(self._zipFileRegexp('epoc32_include.*'))
        if self.options.epoc32_release:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release.*'))
            regexpList.append(self._zipFileRegexp('epoc32_winscw'))
        if self.options.epoc32_release_armv5:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5.*'))
        if self.options.epoc32_release_armv5_urel:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5.*wpx'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5_urel.*'))
        if self.options.epoc32_release_armv5_udeb:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5.*wpx'))
            regexpList.append(self._zipFileRegexp('epoc32_release_armv5_udeb.*'))
        if self.options.epoc32_release_winscw:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw.*'))
        if self.options.epoc32_release_winscw_urel:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw.*wpx'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw_urel.*'))
        if self.options.epoc32_release_winscw_udeb:
            self._appendEpoc32(regexpList)
            regexpList.append(self._zipFileRegexp('epoc32_release'))
            regexpList.append(self._zipFileRegexp('epoc32_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw.*wpx'))
            regexpList.append(self._zipFileRegexp('epoc32_release_winscw_udeb.*'))
        if self.options.epoc32_release_map:
            regexpList.append(self._zipFileRegexp('epoc32_.*map'))
        if self.options.source:
            regexpList.append(self._zipFileRegexp('.*source.*'))
        if self.options.minienv:
            regexpList.append(self._zipFileRegexp('minienv_' + self.options.minienv))
        if self.options.target:
            regexpList.append(self._zipFileRegexp('targets_' + self.options.target + ".*"))
        if self.options.internal_code:
            regexpList.append(self._zipFileRegexp('internal_code_.*'))
        if self.options.localisation:
            regexpList.append(self._zipFileRegexp('epoc32_localisation.*'))
        if self.options.overlay:
            regexpList.append(self._zipFileRegexp('.*overlay.*'))
        if self.options.symbols:
            regexpList.append(self._zipFileRegexp('symbols_logs_' + self.options.symbols))
        outputList = []
        for entry in inputList:
            for regexp in regexpList:
                if regexp.match(entry):
                    outputList.append(entry)
                    break
        return outputList

    def includedRemoteZipFileList(self):
        return self._filterZipFileList(self.remoteZipFileList())

    def includedLocalZipFileList(self):
        return self._filterZipFileList(self.localZipFileList())

    def excludedRemoteZipFileList(self):
        return ExcludedFrom(self.remoteZipFileList(), self.includedRemoteZipFileList())

    def excludedLocalZipFileList(self):
        return ExcludedFrom(self.localZipFileList(), self.includedLocalZipFileList())

    def fetch(self):
        remoteList = self.includedRemoteZipFileList()

        # Check which files are already present
        localList = []
        transferList = []
        for entry in remoteList:
            localPath = os.path.join(self.localDir(), entry)
            if os.path.exists(localPath):
                localList.append(entry)
            else:
                transferList.append(entry)

        print "\nIncluded:"
        for entry in remoteList:
            print "    " + entry

        print "\nExcluded:"
        for entry in self.excludedRemoteZipFileList():
            print "    " + entry

        print "\nAlready in local directory:"
        for entry in localList:
            print "    " + entry

        print "\nTo be transferred:"
        for entry in transferList:
            print "    " + entry

        print "\nRemote directory: " + self.remoteDir()
        print "Local directory:  " + self.localDir()

        if not self.options.dry_run:
            # Write readme.txt into destination directory
            readmeFileName = os.path.join(self.localDir(), 'readme.txt')
            readmeFile = open(readmeFileName, 'w')
            readmeFile.write('This directory contains files fetched by hydra.py\n')
            readmeFile.write('\n')
            readmeFile.write('Project:          ' + self.project.name + '\n')
            readmeFile.write('Version:          ' + self.version + '\n')
            readmeFile.write('Remote directory: ' + self.remoteDir() + '\n')
            readmeFile.write('Local directory:  ' + self.localDir() + '\n')
            readmeFile.write('\n')
            readmeFile.write('Included zip files:\n')
            for entry in remoteList:
                readmeFile.write('    ' + entry + '\n')
            readmeFile.write('\n')
            readmeFile.write('\nExcluded zip files:\n')
            for entry in self.excludedRemoteZipFileList():
                readmeFile.write('    ' + entry + '\n')
            readmeFile.close()

            count = 0
            print "\nStarting transfer ..."
            for entry in transferList:
                count = count + 1
                print "\n" + entry + " (" + str(count) + " / " + str(len(transferList)) + ")"
                localPath = os.path.join(self.localDir(), entry)
                remotePath = os.path.join(self.remoteDir(), entry)
                file_size = os.stat(remotePath).st_size
                p = ProgressBar(totalWidth = 40, maxValue = file_size)
                fileCopy(remotePath, localPath, callback = lambda pos: p.update(pos))

    def unzip(self, destDir):
        print "Destination directory:\n    " + destDir + "\n"
        localList = self.includedLocalZipFileList()
        print "\nTo be unzipped:"
        for entry in localList:
            print "    " + entry
        print "\nNot to be unzipped:"
        for entry in self.excludedLocalZipFileList():
            print "    " + entry
        if not self.options.dry_run:
            # Write readme.txt into destination directory
            readmeFileName = os.path.join(destDir, 'readme.txt')
            readmeFile = open(readmeFileName, 'w')
            readmeFile.write('This directory contains files unzipped by hydra.py\n')
            readmeFile.write('\n')
            readmeFile.write('Project:          ' + self.project.name + '\n')
            readmeFile.write('Version:          ' + self.version + '\n')
            readmeFile.write('\n')
            readmeFile.write('Included zip files:\n')
            for entry in localList:
                readmeFile.write('    ' + entry + '\n')
            readmeFile.write('\n')
            readmeFile.write('\nExcluded zip files:\n')
            for entry in self.excludedLocalZipFileList():
                readmeFile.write('    ' + entry + '\n')
            readmeFile.close()

        log = None
        if not self.options.dry_run:
            log = open("hydra.log", "a")
        print "\nStarting unzip ..."
        count = 0
        for entry in localList:
            count = count + 1
            print "\nUnzipping " + entry + " (" + str(count) + " / " + str(len(localList)) + ")"
            if not self.options.dry_run:
                log.write(entry + " (" + str(count) + " / " + str(len(localList)) + ")\n")
            cmd = "7z"
            cmd += " x " + os.path.join(self.localDir(), entry)
            cmd += " -o" + destDir
            cmd += " -y"
            Call(cmd, self.options)


#------------------------------------------------------------------------------
# Subroutines
#------------------------------------------------------------------------------

def CreateCommandLineParser():
    parser = OptionParser()
    usage = sys.argv[0] + " command [args] [options]"
    usage += "\n\nCommands:"
    usage += "\n  projects                   Print list of projects"
    usage += "\n  test <project> <version>"
    usage += "\n  fetch <project> <version>  Fetch zip files from server"
    usage += "\n  unzip <project> <version> <dest>  Unzip files"
    parser.set_usage(usage)
    parser.add_option('-i', '--ini', type='string', dest='ini_filename',
                      help='INI file name')
    parser.add_option('-n', '--dry-run', dest='dry_run', action='store_true',
                      default=False, help='Do not actually execute any actions')
    parser.add_option('-q', '--quiet', dest='quiet', action='store_true',
                      default=False, help='No output')
    parser.add_option('-s', '--server', type='string', dest='server', help='Server')
    parser.add_option('-v', '--verbose', dest='verbose', action='store_true',
                      default=False, help='Verbose output')

    headers = OptionGroup(parser, "Headers", "")
    headers.add_option('', '--headers', dest='epoc32_include', action='store_true',
                      default=False, help='Include epoc32/include')
    parser.add_option_group(headers)

    binaries = OptionGroup(parser, "Binaries", "")
    binaries.add_option('', '--binaries', dest='epoc32_release', action='store_true',
                      default=False, help='Include all binaries')
    binaries.add_option('', '--armv5', dest='epoc32_release_armv5', action='store_true',
                      default=False, help='Include release/armv5 binaries (implies --armv5-udeb --armv5-urel)')
    binaries.add_option('', '--armv5-udeb', dest='epoc32_release_armv5_udeb', action='store_true',
                      default=False, help='Include release/armv5/udeb binaries')
    binaries.add_option('', '--armv5-urel', dest='epoc32_release_armv5_urel', action='store_true',
                      default=False, help='Include release/armv5/urel binaries')
    binaries.add_option('', '--winscw', dest='epoc32_release_winscw', action='store_true',
                      default=False, help='Include release/winscw binaries (implies --winscw-udeb --winscw-urel)')
    binaries.add_option('', '--winscw-udeb', dest='epoc32_release_winscw_udeb', action='store_true',
                      default=False, help='Include release/winscw/udeb binaries')
    binaries.add_option('', '--winscw-urel', dest='epoc32_release_winscw_urel', action='store_true',
                      default=False, help='Include release/winscw/urel binaries')
    binaries.add_option('', '--map', dest='epoc32_release_map', action='store_true',
                      default=False, help='Include .map files')
    parser.add_option_group(binaries)

    source = OptionGroup(parser, "Source", "")
    source.add_option('', '--src', dest='source', action='store_true',
                      default = False, help='Source')
    parser.add_option_group(source)

    env = OptionGroup(parser, "Environments", "")
    env.add_option('', '--minienv', dest='minienv', type='string',
                   help='Minienv (e.g. vasco')
    parser.add_option_group(env)

    targets = OptionGroup(parser, "Targets", "")
    targets.add_option('', '--target', dest='target', type='string',
                      help='Include ROM images (e.g. vasco_rnd)')
    parser.add_option_group(targets)

    misc = OptionGroup(parser, "Miscellaneous", "")
    misc.add_option('', '--internal-code', dest='internal_code', action='store_true',
                    default=False, help='Internal code')
    misc.add_option('', '--localisation', dest='localisation', action='store_true',
                    default=False, help='Localisation')
    headers.add_option('', '--overlay', dest='overlay', action='store_true',
                      default=False, help='Include overlays')
    parser.add_option_group(misc)

    debugging = OptionGroup(parser, "Debugging", "")
    debugging.add_option('', '--symbols', dest='symbols', type='string',
                      help='Include symbols (e.g. vasco)')
    parser.add_option_group(debugging)

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
        defaultIniPath = os.path.join(os.environ.get('METASYSTEM_CONFIG'), 'hydra.ini')
        if os.path.exists(defaultIniPath):
            result['options'].ini_filename = defaultIniPath
        else:
            UsageError("No INI file path specified")

    if None == result['options'].server:
        UsageError("No server specified")

    return result


def ExtractRequiredIniField(parser, section, field, host = None):
    result = None
    if host and parser.has_option(section, '{' + host + '}' + field):
        result = parser.get(section, '{' + host + '}' + field)
    else:
        if parser.has_option(section, field):
            result = parser.get(section, field)
        else:
            raise IOError("Required field '" + field + "' in section '" \
                       + section + "' not found in config file")
    return result


def ExtractOptionalIniField(parser, section, field, host = None):
    result = None
    if host and parser.has_option(section, '{' + host + '}' + field):
        result = parser.get(section, '{' + host + '}' + field)
    else:
        if parser.has_option(section, field):
            result = parser.get(section, field)
    return result


def ExtractOptionalIniFieldBool(parser, section, field, host = None, default = False):
    result = default
    value = ExtractOptionalIniField(parser, section, field, host)
    valueDict = {
        'true' : True,
        'false' : False
    }
    if value:
        result = valueDict[value]
    return result


def ParseIniFile(options):
    config = { }

    parser = ConfigParser.RawConfigParser()
    fileName = options.ini_filename
    if len(parser.read(fileName)) == 0:
        raise IOError("Failed to read config file " + fileName)

    config['local_root'] = ExtractRequiredIniField(parser, 'local', 'path')
    config['remote_root'] = ExtractRequiredIniField(parser, 'remote', options.server)

    projects = []
    for section in parser.sections():
        if section.startswith('project:'):
            projects.append(section[8:])

    ParseProjects(parser, projects, config)

    return config


def ParseProjects(parser, names, config):
    config['projects'] = { }
    for name in names:
        section = 'project:' + name
        path = ExtractRequiredIniField(parser, section, 'path')
        version_dir = ExtractRequiredIniField(parser, section, 'version_dir')
        zip_prefix = ExtractRequiredIniField(parser, section, 'zip_prefix')
        config['projects'][name] = Project(name, path, version_dir, zip_prefix)


def InvalidAction(commandLine, config):
    UsageError("Invalid action '" + commandLine['command'] + "'")


#------------------------------------------------------------------------------
# Action implementations
# None of these should throw an exception; each one must return True or False
# to indicate overall success
#------------------------------------------------------------------------------

def ActionProjects(commandLine, config):
    for project in config['projects']:
        print config['projects'][project]
    return True

def ActionTest(commandLine, config):
    if len(commandLine['args']) >= 2:
        projectName = commandLine['args'][1]
        version = commandLine['args'][2]
        project = config['projects'][projectName]
        environment = Environment(commandLine['options'], config, project, version)
        print environment
        all = environment.remoteZipFileList()

        print "Included:"
        for x in environment.includedRemoteZipFileList():
            print x

        print "\nExcluded:"
        for x in environment.excludedRemoteZipFileList():
            print x

    else:
        UsageError('Invalid project / version')

    return True

def ActionFetch(commandLine, config):
    timer = DurationTimer('fetch')
    if len(commandLine['args']) >= 2:
        projectName = commandLine['args'][1]
        version = commandLine['args'][2]
        project = config['projects'][projectName]
        environment = Environment(commandLine['options'], config, project, version)
        print environment
        localDir = environment.localDir()
        if not os.path.exists(localDir):
            print "Creating local directory " + localDir
            if not commandLine['options'].dry_run:
                os.makedirs(localDir)
        environment.fetch()
    print timer
    return True

def ActionUnzip(commandLine, config):
    if len(commandLine['args']) >= 3:
        projectName = commandLine['args'][1]
        version = commandLine['args'][2]
        destDir = commandLine['args'][3]
        project = config['projects'][projectName]
        environment = Environment(commandLine['options'], config, project, version)
        print environment
        environment.unzip(destDir)
    return True


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_env()

commandLine = ProcessCommandLine()
config = ParseIniFile(commandLine['options'])

commandLine['command'] = 'projects'

if len(commandLine['args']):
    commandLine['command'] = commandLine['args'][0]

dispatch = {
                'projects': ActionProjects
           ,    'fetch':    ActionFetch
           ,    'unzip':    ActionUnzip
           ,    'test':     ActionTest
           }

success = dispatch.get(commandLine['command'], ActionProjects)(commandLine, config)

exitCode = 0
if not success:
    exitCode = 1
exit(exitCode)

