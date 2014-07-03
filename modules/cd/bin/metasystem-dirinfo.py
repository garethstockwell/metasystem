#!/usr/bin/env python

# metasystem-dirinfo

# Supported commands:
#   label <label>
#   id <key> <value>
#   project <name> [source=<dir>] [build=<dir>]
#   shell <command> [args...]
#   tool <key> <value>

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import os
import os.path
import re

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80
COLOR_LIGHT_RED = '${NAKED_LIGHT_RED}'
COLOR_NONE = '${NAKED_NO_COLOR}'

REQUIRED_VARS = ['METASYSTEM_CORE_CONFIG', 'METASYSTEM_PLATFORM']

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'metasystem-dirinfo'
        epilog = '''
        Parser for .metasystem-dirinfo files
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        self.add_argument('-f', '--file',
                          dest='file', default=None,
                          help='.metasystem-dirinfo file')
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-v', '--verbose',
                          dest='verbose', default=False,
                          action='store_true',
                          help='produce verbose output')
        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

#------------------------------------------------------------------------------
# The guts
#------------------------------------------------------------------------------

class Command:
    def __init__(self, line, tokens, line_number):
        self.command = tokens.pop(0)
        self.line = line
        self.tokens = tokens
        self.line_number = line_number
        self.args = []
        self.options = {}
        option_regex = re.compile(r"(.*)=(.*)")
        for token in tokens:
            option_match = option_regex.match(token)
            if option_match:
                [key, value] = option_match.groups()
                self.options[key] = value
            else:
                self.args.append(token)

    def __repr__(self):
        result = '[{0:d}] {1:s}'.format(self.line_number, self.command)
        for arg in self.args:
            result += "\n    arg [{0:s}]".format(arg)
        for key in self.options.keys():
            value = self.options[key]
            result += "\n    option [{0:s}] = [{1:s}]".format(key, value)
        return result

def abspath_mingw(path):
    path = path.replace('\\', '/')
    return path

def process_file(args):
    fh = open(args.file, 'r')
    commands = []
    comment_regex = re.compile(r"#.*")
    line_number = 0
    while True:
        line = fh.readline()
        if len(line) == 0:
            break
        line_number = line_number + 1
        line = comment_regex.sub('', line)
        line = line.strip()
        tokens = line.split()
        if len(tokens):
            commands.append(Command(line, tokens, line_number))
    fh.close()
    handlers = {'label':    handle_label
               ,'id':       handle_id
               ,'project':  handle_project
               ,'shell':    handle_shell
               ,'tool':     handle_tool
               }
    context = {'label':     None
              ,'ids':       []
              ,'projects':  []
              ,'tools':     []
              }
    context['output'] = open(args.file + '.sh', 'w')
    [filedir, filename] = os.path.split(args.file)
    context['dir'] = os.path.abspath(filedir)
    preamble(context)
    for command in commands:
        handler = handlers.get(command.command)
        if handler:
            handler(command, context)
        else:
            raise IOError("Invalid command '{0:s}'".format(command.command))
    postamble(context)

def preamble(context):
    pass

def postamble(context):
    postamble_projects(context)

def postamble_projects(context):
    context['output'].write("\n# projects postamble\n")
    for project in (os.environ.get('METASYSTEM_PROJECTS') or '').split():
        if not project in context['projects']:
            context['output'].write("_metasystem_set_projectdirs {0:s} '' ''\n".format(project))
    context['output'].write("_metasystem_export METASYSTEM_PROJECTS='{0:s}'\n".format(' '.join(context['projects'])))

def check_args_count(command, count):
    assert len(command.args) >= count, 'Insufficient arguments on line {0:d}'.format(command.line_number)
    if len(command.args) > count:
        print 'Warning: extra arguments ignored on line {0:d}'.format(command.line_number)

def check_options(command, valid_options):
    for option in command.options.keys():
        if not option in valid_options:
            print 'Warning: extra options ignored on line {0:d}'.format(command.line_number)

def handle_label(command, context):
    check_args_count(command, 1)
    check_options(command, [])
    assert not context['label'], 'Repeated label on line {0:d}'.format(command.line_number)
    [label] = command.args
    context['output'].write("\n# [{0:d}] {1:s}\n".format(command.line_number, command.line))
    context['output'].write("_metasystem_export METASYSTEM_DIRINFO_LABEL='{0:s}'\n".format(label))
    context['label'] = label

def handle_id(command, context):
    check_args_count(command, 2)
    check_options(command, [])
    [key, value] = command.args
    assert not key in context['ids'], 'Repeated id on line {0:d}'.format(command.line_number)
    context['output'].write("\n# [{0:d}] {1:s}\n".format(command.line_number, command.line))
    context['output'].write("echo -e \"{0:s}id: {1:s}={2:s}{3:s}\"\n".format(COLOR_LIGHT_RED, key, value, COLOR_NONE))
    context['output'].write("_metasystem_set_id {0:s} {1:s}\n".format(key, value))
    context['ids'].append(key)

def handle_project(command, context):
    check_args_count(command, 1)
    check_options(command, ['dir', 'sourcedir', 'builddir', 'chroot'])
    [name] = command.args
    assert not name in context['projects'], 'Repeated project on line {0:d}'.format(command.line_number)
    projectdir = ''
    if 'dir' in command.options.keys():
        projectdir = command.options['dir']
    sourcedir = projectdir
    if 'sourcedir' in command.options.keys():
        sourcedir = command.options['sourcedir']
    builddir = projectdir
    if 'builddir' in command.options.keys():
        builddir = command.options['builddir']
    assert builddir != '', 'Build directory not specified on line {0:d}'.format(command.line_number)
    if not builddir.startswith('/'):
        builddir = os.path.join(context['dir'], builddir)
    if sourcedir != '' and not sourcedir.startswith('/'):
        sourcedir = os.path.join(context['dir'], sourcedir)
    if os.environ.get('METASYSTEM_PLATFORM') == 'mingw':
        sourcedir = abspath_mingw(sourcedir)
        builddir = abspath_mingw(builddir)
    context['output'].write("\n# [{0:d}] {1:s}\n".format(command.line_number, command.line))
    context['output'].write("_metasystem_set_projectdirs {0:s} $(metasystem_unixpath \"{1:s}\") $(metasystem_unixpath \"{2:s}\")\n".format(name, builddir, sourcedir))
    if 'chroot' in command.options.keys():
        chroot = command.options['chroot']
        context['output'].write("_metasystem_set_project_chroot {0:s} {1:s}".format(name, chroot))
    context['projects'].append(name)

def handle_shell(command, context):
    deprecate = os.environ.get('METASYSTEM_DIRINFO_SHELL_DEPRECATE')
    ignore = os.environ.get('METASYSTEM_DIRINFO_SHELL_IGNORE')
    if ignore == 'yes':
        print "Warning: use of 'shell' keyword in metasystem-dirinfo files is ignored"
    else:
        if deprecate == 'yes':
            print "Warning: use of 'shell' keyword in metasystem-dirinfo files is deprecated"
        context['output'].write("\n# [{0:d}] {1:s}\n".format(command.line_number, command.line))
        context['output'].write(' '.join(command.tokens) + "\n")

def handle_tool(command, context):
    check_args_count(command, 2)
    check_options(command, [])
    [key, value] = command.args
    assert not key in context['ids'], 'Repeated tool on line {0:d}'.format(command.line_number)
    context['output'].write("\n# [{0:d}] {1:s}\n".format(command.line_number, command.line))
    context['output'].write("echo -e \"{0:s}tool: {1:s}={2:s}{3:s}\"\n".format(COLOR_LIGHT_RED, key, value, COLOR_NONE))
    context['output'].write("_metasystem_set_tool {0:s} {1:s}\n".format(key, value))
    context['tools'].append(key)

def clear(args):
    project_list = os.environ.get('METASYSTEM_PROJECTS')
    projects = []
    if project_list:
        projects = project_list.split()
    output = open(os.path.join(os.environ.get('HOME'), '.metasystem-dirinfo.sh'), 'w')
    output.write('# Clearing metasystem dirinfo\n')
    for project in projects:
        project = project.replace('-', '_')
        output.write('_metasystem_unset METASYSTEM_PROJECT_{0:s}_BUILD_DIR\n'.format(project.upper()))
        output.write('_metasystem_unset METASYSTEM_PROJECT_{0:s}_SOURCE_DIR\n'.format(project.upper()))
    output.write('_metasystem_export METASYSTEM_PROJECTS=\n')


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def check_env():
    for var in REQUIRED_VARS:
        value = os.environ.get(var)
        if value == None or value == '':
            raise IOError("Environment variable '{0:s}' not set".format(var))

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
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    for key in sorted(list(set(keys) - set(initial_group))):
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    print '-' * LINE_WIDTH

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_env()
args = parse_command_line()
if args.verbose:
    print_summary(args, ('file'))
if args.file:
    process_file(args)
else:
    clear(args)

