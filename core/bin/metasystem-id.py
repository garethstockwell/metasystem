#!/usr/bin/env python

# metasystem-id

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import ConfigParser
import os
import os.path
import re
import sys

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80
SEPARATOR = '-'
HOME_PATH = os.path.expanduser('~')

REQUIRED_VARS = ['METASYSTEM_CORE_CONFIG', 'METASYSTEM_CORE_TEMPLATES']

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class IdentityType:
    def __init__(self, name, config_file):
        self.name = name
        self.config_file = config_file
        self.current_id = None

    def __repr__(self):
        s = "    " + self.name + ":\n"
        s += "        config_file = " + self.config_file + "\n"
        s += "        current_id = " + (self.current_id or '')
        return s

class Identity:
    def __init__(self, name):
        self.name = name
        self.subst = dict()

    def __repr__(self):
        s = "    " + self.name + ":"
        if len(self.subst.keys()):
            for key in self.subst.keys():
                s += "\n        " + key + " = " + self.subst[key]
        else:
            s += "\n"
        return s

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = '[CHANGE] A dummy description'
        epilog = '''
        [CHANGE] A dummy epilog string
        '''
        version = '[CHANGE] 0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Options
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-v', '--verbose',
                          dest='verbose', default=False,
                          action='store_true',
                          help='produce verbose output')
        self.add_argument('-q', '--quiet',
                          dest='quiet', default=False,
                          action='store_true',
                          help='produce quiet output')

        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

        subparsers = self.add_subparsers(help='subcommands',
                                         parser_class=argparse.ArgumentParser)

        # Subcommand list
        parser_generate = subparsers.add_parser('generate', help='Generate identity file')
        parser_generate.add_argument('-t', '--type', default=None,
                                     help='Type of config file to generate')
        parser_generate.add_argument('-r', '--reset',
                                     dest='reset', default=False,
                                     action='store_true',
                                     help='Reset to default identities')
        parser_generate.add_argument('-s', '--script',
                                     dest='script', default=False,
                                     action='store_true',
                                     help='Generate ~/.metasystem-id')

        parser_generate.set_defaults(func=cmd_generate)

        # Subcommand list
        parser_list = subparsers.add_parser('list', help='List available identities')
        parser_list.set_defaults(func=cmd_list)

        # Subcommand print
        parser_print = subparsers.add_parser('print', help='Print existing identities')
        parser_print.set_defaults(func=cmd_print)

        # Subcommand set
        parser_set = subparsers.add_parser('set', help='Set identity')
        parser_set.add_argument('type')
        parser_set.add_argument('id')
        parser_set.set_defaults(func=cmd_set)

#------------------------------------------------------------------------------
# INI file parsing
#------------------------------------------------------------------------------

def extract_required_field(parser, section, field):
    result = None
    if parser.has_option(section, field):
        result = parser.get(section, field)
    else:
        raise IOError, "Required field '" + field + "' in section '" \
                       + section + "' not found in config file"
    return result

def extract_optional_field(parser, section, field):
    result = None
    if parser.has_option(section, field):
        result = parser.get(section, field)
    return result

def add_type(parser, typeName, config):
    sectionName = 'type' + SEPARATOR + typeName
    configFile = extract_required_field(parser, sectionName, 'config_file')
    config['types'][typeName] = IdentityType(typeName, configFile)

def add_id(parser, idName, config):
    sectionName = 'id' + SEPARATOR + idName
    idObject = Identity(idName)
    for option in parser.options(sectionName):
        bits = option.partition(SEPARATOR)
        if bits[0] == 'subst':
            idObject.subst[bits[2].upper()] = parser.get(sectionName, option)
    config['ids'][idName] = idObject

def parse_ini(args):
    config = { }
    config['types'] = { }
    config['ids'] = { }

    fileName = os.path.join(os.environ.get('METASYSTEM_CORE_CONFIG'), 'id.ini')
    parser = ConfigParser.RawConfigParser()
    if len(parser.read(fileName)) == 0:
        raise IOError, "Failed to read config file " + fileName

    config['default_id'] = parser.get('common', 'default_id')

    for section in parser.sections():
        bits = section.partition(SEPARATOR)
        if bits[1] != '':
            sectionType = bits[0]
            sectionName = bits[2]
            if sectionType == 'type':
                add_type(parser, sectionName, config)
            if sectionType == 'id':
                add_id(parser, sectionName, config)

    return config

#------------------------------------------------------------------------------
# Subcommand implementations
#------------------------------------------------------------------------------

def print_types(config):
    print "types:"
    for typeObject in config['types'].values():
        print typeObject

def print_ids(config):
    print "ids:"
    for idObject in config['ids'].values():
        print idObject

def get_current_ids(config):
    for type in config['types'].values():
        envVarName = 'METASYSTEM_ID_' + type.name.upper()
        type.current_id = config['default_id']
        if envVarName in os.environ.keys():
            type.current_id = os.environ[envVarName]

def cmd_print(args, config):
    for type in config['types'].values():
        print type.name, '=', (type.current_id or '')

def cmd_list(args, config):
    if args.verbose:
        print_types(config)
        print_ids(config)
    else:
        print "types:", str.join(' ', config['types'].keys())
        print "ids:", str.join(' ', config['ids'].keys())

def do_write_config_file(args, sourceFileName, type, id, overlay=False):
    config_file = type.config_file
    destFileName = os.path.join(HOME_PATH, '.' + config_file)
    if os.path.isfile(sourceFileName):
        if not args.quiet:
            print "Generating file ~/." + config_file
        sourceFile = open(sourceFileName, 'r')
        destFile = open(destFileName, 'wb')
        subst = os.environ
        subst.update(id.subst)
        regexp = re.compile('\$\{(.*?)\}')
        for line in sourceFile:
            matches = regexp.findall(line)
            for m in matches:
                line = line.replace('${' + m + '}', subst.get(m, ''))
            destFile.write(line)
        return
    if overlay:
        return
    if os.path.isfile(destFileName):
        if not args.quiet:
            print "Removing file ~/." + config_file
        os.remove(destFileName)

def write_config_file(args, type, id):
    template = os.path.join(os.environ.get('METASYSTEM_ROOT'), 'modules', type.name, 'dotfiles', type.config_file)
    do_write_config_file(args, template, type, id)
    template = os.path.join(os.environ.get('METASYSTEM_LOCAL_DOTFILES'), type.name, 'dotfiles', type.config_file)
    do_write_config_file(args, template, type, id, overlay=True)

def write_shell_script(args, config):
    if not args.quiet:
        print "Generating file ~/.metasystem-id"
    fileName = os.path.join(HOME_PATH, '.metasystem-id')
    file = open(fileName, 'wb')
    file.write("# Generated by metasystem-id.py\n\n")
    file.write("_metasystem_export METASYSTEM_ID_TYPES='" + str.join(' ', config['types'].keys()) + "'\n")
    file.write("_metasystem_export METASYSTEM_IDS='" + str.join(' ', config['ids'].keys()) + "'\n")
    values = ''
    for type in config['types'].values():
        envVarName = 'METASYSTEM_ID_' + type.name.upper()
        file.write("_metasystem_export " + envVarName + "=" + (type.current_id or '') + "\n")
        if len(values):
            values += ';'
        values += type.name + ':' + type.current_id
    file.write("\n_metasystem_export METASYSTEM_ID_VALUES='" + values + "'\n")

def cmd_set(args, config):
    if not args.type in config['types']:
        print_types(config)
        print
        raise IOError, "type '" + args.type + "' not recognized"
    type = config['types'][args.type]
    if not args.id in config['ids']:
        print_ids(config)
        print
        raise IOError, "id '" + args.id + "' not recognized"
    id = config['ids'][args.id]
    type.current_id = args.id
    write_shell_script(args, config)

def cmd_generate(args, config):
    types = []
    if args.type:
        types.append(config['types'][args.type])
    else:
        types = config['types'].values()
    for type in types:
        if args.reset:
            type.current_id = config['default_id']
        id = config['ids'][type.current_id]
        write_config_file(args, type, id)
    if args.script:
        write_shell_script(args, config)

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def check_env():
    for var in REQUIRED_VARS:
        value = os.environ.get(var)
        if value == None or value == '':
            raise IOError, "Environment variable '{0:s}' not set".format(var)

def print_error(message):
    print >> sys.stderr, 'Error:', message

def parse_command_line():
    '''
    Return: argparse.Namespace
    '''
    parser = ArgumentParser()
    return parser.parse_args()

def print_summary(args):
    '''
    Print results of parsing command line
    '''
    keys = [name for name in dir(args) if not name.startswith('_')]
    keys.remove('func')
    keys.append('subcommand')
    maxkeylen = max([len(key) for key in keys])
    keys.remove('subcommand')
    values = [len(str(getattr(args, key))) for key in keys]
    values.append(args.func.func_name)
    maxvaluelen = max([len(str(value)) for value in values])
    rightcolpos = LINE_WIDTH - maxvaluelen - 4
    print '-' * LINE_WIDTH
    print 'Summary of options'
    print '-' * LINE_WIDTH
    print ' subcommand', ('.' * (rightcolpos - len('subcommand') - 2)), args.func.func_name
    for key in sorted(list(set(keys))):
        print ' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key)
    print '-' * LINE_WIDTH
    print

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_env()
args = parse_command_line()
if args.verbose:
    print_summary(args)
config = parse_ini(args)
get_current_ids(config)
args.func(args, config)

