#!/usr/bin/env python

# metasystem-tools

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

REQUIRED_VARS = ['METASYSTEM_CORE_CONFIG', 'METASYSTEM_OS']

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class Type:
    def __init__(self, name, default_tool):
        self.name = name
        self.default_tool = default_tool
        self.current_tool = None

    def __repr__(self):
        s = "    " + self.name + ":\n"
        s += "        default_tool = " + (self.default_tool or '') + "\n"
        s += "        current_tool = " + (self.current_tool or '') + "\n"
        return s

class Tool:
    def __init__(self, name, type, prepend):
        self.name = name
        self.type = type
        self.prepend = []
        if prepend:
            self.prepend = prepend
        self.alias = None
        self.var = { }
        self.env = { }

    def __repr__(self):
        s = "    " + self.name + ":\n"
        s += "        type = " + self.type + "\n"
        s += "        vars:\n"
        for x in self.var.keys():
            s += "            " + x + " = " + self.var[x] + "\n"
        s += "        env:\n"
        for x in self.env.keys():
            s += "            " + x + " = " + self.env[x] + "\n"
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
        self.add_argument('-V', '--version',
                          dest='version',
                          action='version',
                          version=version,
                          help="show program's version number and exit")

        subparsers = self.add_subparsers(help='subcommands',
                                         parser_class=argparse.ArgumentParser)

        # Subcommand list
        parser_generate = subparsers.add_parser('generate', help='Autogenerate config file')
        parser_generate.set_defaults(func=cmd_generate)

        # Subcommand list
        parser_list = subparsers.add_parser('list', help='List available tools')
        parser_list.set_defaults(func=cmd_list)

        # Subcommand print
        parser_print = subparsers.add_parser('print', help='Print current tools')
        parser_print.set_defaults(func=cmd_print)

        # Subcommand set
        parser_set = subparsers.add_parser('set', help='Set tool')
        parser_set.add_argument('type')
        parser_set.add_argument('tool')
        parser_set.set_defaults(func=cmd_set)

#------------------------------------------------------------------------------
# INI file parsing
#------------------------------------------------------------------------------

def extract_required_field(parser, section, field):
    result = None
    if parser.has_option(section, field):
        result = parser.get(section, field)
    else:
        raise IOError("Required field '" + field + "' in section '" \
                       + section + "' not found in config file")
    return result

def extract_optional_field(parser, section, field):
    result = None
    if parser.has_option(section, field):
        result = parser.get(section, field)
    return result

def add_type(parser, name, config):
    sectionName = 'type' + SEPARATOR + name
    default_tool = extract_optional_field(parser, sectionName, 'default_tool')
    config['types'][name] = Type(name, default_tool)

def add_tool(parser, name, config):
    sectionName = 'tool' + SEPARATOR + name
    osList = extract_required_field(parser, sectionName, 'os').split(' ')
    osMatch = False
    for osName in osList:
        if osName == os.environ.get('METASYSTEM_OS') or osName == '*':
            osMatch = True
    if osMatch:
        typeName = extract_required_field(parser, sectionName, 'type')
        prependString = extract_optional_field(parser, sectionName, 'prepend')
        prepend = None
        if prependString:
            prepend = prependString.split(' ')
        tool = Tool(name, typeName, prepend)
        tool.alias = extract_optional_field(parser, sectionName, 'alias')
        for option in [x for x in parser.options(sectionName) if x.startswith('var-')]:
            key = option[4:]
            value = parser.get(sectionName, option)
            tool.var[key] = value
        for option in [x for x in parser.options(sectionName) if x.startswith('env-')]:
            key = option[4:].upper()
            value = parser.get(sectionName, option)
            tool.env[key] = value
        config['tools'][name] = tool
        type = config['types'][typeName]

def parse_ini(args):
    config = { }
    config['tools'] = { }
    config['types'] = { }
    fileName = os.path.join(os.environ.get('METASYSTEM_CORE_CONFIG'), 'tools.ini')
    parser = ConfigParser.RawConfigParser()
    if len(parser.read(fileName)) == 0:
        raise IOError("Failed to read config file " + fileName)
    for section in parser.sections():
        bits = section.partition(SEPARATOR)
        if bits[1] != '':
            sectionType = bits[0]
            sectionName = bits[2]
            if sectionType == 'type':
                add_type(parser, sectionName, config)
            if sectionType == 'tool':
                add_tool(parser, sectionName, config)
    return config

#------------------------------------------------------------------------------
# Subcommand implementations
#------------------------------------------------------------------------------

def print_types(config):
    print "types:"
    for type in config['types'].values():
        print type

def print_tools(config):
    print "tools:"
    for tool in config['tools'].values():
        print tool

def get_current_tools(config):
    for type in config['types'].values():
        envVarName = 'METASYSTEM_TOOL_' + type.name.upper()
        type.current_tool = os.environ.get(envVarName)

def subst_vars(src, dest):
    regexp = re.compile('\$\{(.*?)\}')
    result = dest.copy()
    while True:
        changed = False
        for key in result.keys():
            value = result[key]
            oldValue = value
            for substKey in regexp.findall(value):
                substPat = '${' + substKey + '}'
                substValue = result.get(substKey)
                if not substValue:
                    substValue = src.get(substKey, substPat)
                value = value.replace(substPat, substValue)
            changed |= (oldValue != value)
            result[key] = value
        if not changed:
            break
    return result

def cmd_generate(args, config):
    for type in config['types'].values():
        type.current_tool = type.default_tool
    write_shell_script(args, config)

def cmd_print(args, config):
    print_types(config)
    print_tools(config)

def cmd_list(args, config):
    print_types(config)
    print_tools(config)

def write_shell_script(args, config):
    fileName = os.path.join(HOME_PATH, '.metasystem-tools')
    file = open(fileName, 'wb')
    file.write("# Generated by metasystem-tools.py\n\n")
    file.write("_metasystem_export METASYSTEM_TOOL_TYPES='" + str.join(' ', config['types'].keys()) + "'\n")
    for type in config['types'].values():
        file.write("\n_metasystem_export METASYSTEM_TOOL_" + type.name.upper() + "=" + (type.current_tool or '') + "\n")
        if type.current_tool:
            tool = config['tools'][type.current_tool]
            tool.var = subst_vars(os.environ, tool.var)
            tool.env = subst_vars(tool.var, tool.env)
            for key in tool.env.keys():
                value = tool.env[key]
                line = '_metasystem_export ' + key + '='
                if key in tool.prepend:
                    line += '$(path_prepend ' + value + ' ' + '${' + key + '})'
                else:
                    line += value
                file.write(line + "\n")

def cmd_set(args, config):
    if not args.type in config['types']:
        print_types(config)
        print
        raise IOError("type '" + args.type + "' not recognized")
    type = config['types'][args.type]
    tool = None
    if args.tool in config['tools']:
        tool = config['tools'][args.tool]
    else:
        for t in config['tools'].values():
            if t.alias == args.tool:
                tool = t
    if not tool:
        print_tools(config)
        print
        raise IOError("tool '" + args.tool + "' not recognized")
    type.current_tool = tool.name
    write_shell_script(args, config)

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
get_current_tools(config)
args.func(args, config)

