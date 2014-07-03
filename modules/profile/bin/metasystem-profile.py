#!/usr/bin/env python

# metasystem-profile

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import argparse
import ConfigParser
import os
import os.path
import re
import socket
import subprocess
import sys

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80

class Verbosity:
    Silent = 0
    Normal = 1
    Loud = 2

CATEGORIES = ['host', 'location', 'rvct']

REQUIRED_VARS = ['METASYSTEM_CORE_CONFIG', 'METASYSTEM_OS']

#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'metasystem-profile'
        epilog = '''
        Tool for configuring environment variables
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Options
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-q', '--quiet',
                          dest='quiet', default=False,
                          action='store_true',
                          help='suppress output')
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

        parser_set = subparsers.add_parser('set', help='Set profile')
        parser_set.add_argument('-a', '--auto',
                                dest='auto',
                                help='specify categories to auto-detect')
        parser_set.add_argument('-u', '--user',
                                dest='user',
                                help='key-value pairs provided by the user')
        parser_set.add_argument('-r', '--reset',
                                dest='reset', default=False,
                                action='store_true',
                                help='clear values which are not specified in the profile')
        parser_set.set_defaults(func=cmd_set)

        parser_dump = subparsers.add_parser('dump', help='Dump current profile')
        parser_dump.set_defaults(func=cmd_dump)


#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------

def get_ip_linux():
    result = None
    process = subprocess.Popen('ifconfig',
                               shell=True,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
    while (True):
        line = process.stdout.readline()
        if len(line) == 0:
            break
        m = re.search(r'inet addr:(\S+)', line)
        if m:
            addr = m.groups()[0]
            if not addr.startswith('127.0'):
                result = addr
                break
    return result


#------------------------------------------------------------------------------
# Subcommand implementations
#------------------------------------------------------------------------------

def cmd_set(config, args):
    config['categories'] = {}
    config['category_source'] = {}
    config['profile'] = {}
    if args.user:
        for pair in args.user.split(','):
            [category, value] = pair.split('=')
            config['categories'][category] = value
            config['category_source'][category] = 'user'
            env_var = 'METASYSTEM_PROFILE_' + category.upper()
            config['profile'][env_var] = value
    if args.auto:
        print_message('\nAuto-detecting ...', args)
        auto_categories = []
        if args.auto == 'all':
            auto_categories = ['host', 'location']
        else:
            auto_categories = args.auto.split(',')
        for category in auto_categories:
            env_var = 'METASYSTEM_PROFILE_' + category.upper()
            if not env_var in config['profile'].keys():
                function = 'detect_' + category
                value = eval(function)(config, args)
                config['categories'][category] = value
                config['category_source'][category] = 'auto'
                config['profile'][env_var] = value
    if not 'rvct' in config['categories'].keys():
        rvct = config['categories']['location']
        config['categories']['rvct'] = rvct
        config['category_source']['rvct'] = 'implied'
        config['profile']['METASYSTEM_PROFILE_RVCT'] = rvct
    print_message('\nCategories:', args)
    for category in config['categories']:
        value = config['categories'][category]
        source = config['category_source'][category]
        print_message('    [{0:s}] {1:s} = {2:s}'.format(source, category, value), args)
    if not args.dry_run:
        apply_profile(config, args)

def apply_profile(config, args):
    ini = config['parser']
    env_keys = get_env_keys(config)
    if args.reset:
        for env_key in env_keys:
            config['profile'][env_key] = ''
    for env_key in env_keys:
        section = 'env:' + env_key
        for category in config['categories'].keys():
            value = config['categories'][category]
            key_value = '{0:s}({1:s})'.format(category, value or '').lower()
            if ini.has_option(section, key_value):
                env_value = ini.get(section, key_value)
                config['profile'][env_key] = env_value
    profile_file = os.path.join(os.environ.get('HOME'), '.metasystem-profile')
    fh = open(profile_file, 'w')
    max_key_length = max([len(x.strip()) for x in config['profile'].keys()])
    print_message('\nProfile:', args)
    for key in config['profile'].keys():
        value = config['profile'][key] or ''
        if key == 'NETWORK_PROXY':
            set_env_var(args, 'HTTP_PROXY', value, max_key_length, fh)
            set_env_var(args, 'HTTPS_PROXY', value, max_key_length, fh)
            set_env_var(args, 'FTP_PROXY', value, max_key_length, fh)
        else:
            set_env_var(args, key, value, max_key_length, fh)
    fh.close()

def set_env_var(args, key, value, max_key_length, fh):
    key_lc = str.lower(key)
    is_proxy = (key_lc == 'http_proxy' or key_lc == 'https_proxy' or key_lc == 'ftp_proxy')
    print_message('    {0:s} = {1:s}'.format(key, value), args)
    fmt = '    {0:' + str(max_key_length) + 's} = {1:s}'
    fh.write(("\necho \"" + fmt + "\"\n").format(key, value))
    if is_proxy and value == '':
        fh.write("unset {0:s}\n".format(key))
    else:
        fh.write("export {0:s}='{1:s}'\n".format(key, value))
    if is_proxy and os.environ.get('METASYSTEM_OS') == 'linux' and key != key_lc:
        set_env_var(args, key_lc, value, max_key_length, fh)

def cmd_dump(config, args):
    for category in CATEGORIES:
        env_key = 'METASYSTEM_PROFILE_' + category.upper()
        env_value = os.environ.get(env_key)
        print('    {0:s} = {1:s}'.format(env_key, env_value or ''))
    print('Variables:')
    for env_key in get_env_keys(config):
        env_value = os.environ.get(env_key)
        print('    {0:s} = {1:s}'.format(env_key, env_value or ''))


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

def check_env():
    for var in REQUIRED_VARS:
        value = os.environ.get(var)
        if value == None or value == '':
            raise IOError("Environment variable '{0:s}' not set".format(var))

def print_message(msg, args):
    if verbosity(args) == Verbosity.Loud:
        print(msg)

def print_error(message):
    print('Error:', message, file=sys.stderr)

def parse_command_line():
    '''
    Return: argparse.Namespace
    '''
    parser = ArgumentParser()
    return parser.parse_args()

def verbosity(args):
    result = Verbosity.Normal
    if args.verbose:
        result = Verbosity.Loud
    else:
        if args.quiet:
            result = Verbosity.Silent
    return result

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
    print('-' * LINE_WIDTH)
    print('Summary of options')
    print('-' * LINE_WIDTH)
    print(' subcommand', ('.' * (rightcolpos - len('subcommand') - 2)), args.func.func_name)
    for key in sorted(list(set(keys))):
        print(' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key))
    print('-' * LINE_WIDTH)
    print()

def parse_ini_file(args):
    config = {}
    config['parser'] = ConfigParser.RawConfigParser()
    ini_file = os.path.abspath(os.path.join(os.environ.get('METASYSTEM_CORE_CONFIG'), 'profile.ini'))
    if len(config['parser'].read(ini_file)) == 0:
        raise IOError("Failed to read config file " + ini_file)
    return config

def detect_host(config, args):
    ini = config['parser']
    hostname = os.environ.get('METASYSTEM_HOSTNAME')
    host = None
    if 'host' in ini.sections():
        for profile_host in ini.options('host'):
            if hostname.lower() == profile_host.lower():
                host = ini.get('host', profile_host)
    print_message('Hostname {0:s}: host {1:s}'.format(hostname or '', host or ''), args)
    return host

def detect_location(config, args):
    ini = config['parser']
    location = None
    if 'location:ip' in ini.sections():
        ip = socket.gethostbyname(socket.gethostname())
        if os.environ.get('METASYSTEM_OS') == 'linux' and ip.startswith('127.0'):
            x = get_ip_linux()
            if x:
                ip = x
        print_message('Checking IP {0:s}'.format(ip), args)
        for mask in ini.options('location:ip'):
            if not location and re.match(mask, ip):
                location = ini.get('location:ip', mask)
                print_message('    IP matched {0:s}: location {1:s}'.format(mask, location), args)
    if not location and 'location:fqdn' in ini.sections():
        fqdn = socket.getfqdn()
        print_message('Checking FQDN {0:s}'.format(fqdn), args)
        for mask in ini.options('location:fqdn'):
            if not location and re.match(mask, fqdn):
                location = ini.get('location:fqdn', mask)
                print_message(    'FQDN matched {0:s}: location {1:s}'.format(mask, location), args)
    if not location:
        location = 'other'
    return location

def get_env_keys(config):
    ini = config['parser']
    result = []
    for section in ini.sections():
        if section.startswith('env:'):
            result.append(section[4:])
    return result


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

check_env()
args = parse_command_line()
config = parse_ini_file(args)
args.func(config, args)

