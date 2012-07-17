#!/usr/bin/env python

# video-transcode

# Script for transcoding video clips
# This requires ffmpeg to be installed and available on the user's PATH

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

import argparse
import os.path
from subprocess import call

#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80
START_TIME = "00:00:22"
DURATION = "00:00:15"
FFMPEG_OPTIONS = ['-vcodec', 'mpeg4', '-b', '1000k',
                  '-acodec', 'ac3', '-ar', '32000', '-ab', '128k', '-ac', '2',
                  '-threads', '8', '-async', '1']

RESOLUTIONS = {
              'nHD':   [  640,  360 ],
              'qHD':   [  960,  540 ],
              '720p':  [ 1280,  720 ],
              '1080p': [ 1920, 1080 ]
              }

#------------------------------------------------------------------------------
# Classes

class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'video-transcode'
        epilog = '''
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Positional arguments
        self.add_argument('input',
                          metavar='INPUT',
                          help='Input file')
        self.add_argument('resolution_name',
                          metavar='RESOLUTION_NAME',
                          help='Resolution name')

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

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

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

def transcode(args, width, height, label, suffix):
    input_dir = os.path.dirname(args.input)
    input_basename = os.path.basename(args.input)
    input_filename = ''
    input_suffix = ''
    if input_basename.find('.') != -1:
        input_filename = input_basename.rsplit('.', 1)[0]
        input_suffix = input_basename.rsplit('.', 1)[1]
    output_filename = os.path.join(input_dir, input_filename + '-' + label + '.' + suffix)
    size = str(width) + 'x' + str(height)
    args = ['ffmpeg.exe',
            '-i', args.input,
            '-ss', START_TIME, '-t', DURATION,
            '-s', size]
    args.extend(FFMPEG_OPTIONS)
    args.append(output_filename)
    print str.join(' ', args)
    call(args)


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()
if args.verbose:
    print_summary(args, ('input'))

resolution = RESOLUTIONS.get(args.resolution_name)
transcode(args, resolution[0], resolution[1], args.resolution_name, "mp4")

