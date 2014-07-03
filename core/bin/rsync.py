#!/usr/bin/env python

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import os
import re
import subprocess
import sys


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = []

if os.environ['METASYSTEM_PLATFORM'] == 'mingw':
    # MSYS rsync seems to be broken, so we use Cygwin rsync instead

    # Prepend Cygwin to PATH
    os.environ['PATH'] = 'c:\\cygwin\\bin;' + os.environ['PATH']

    # Convert Windows paths to Cygwin format
    for arg in sys.argv[1:]:
        m = re.match(r'^([a-zA-Z]):\/(.*)', arg)
        if m:
            drive = m.group(1).lower()
            path = m.group(2)
            arg = '/cygdrive/' + drive + '/' + path
        args.append(arg)

else:
    args = sys.argv[1:]

cmd = 'rsync ' + ' '.join(args)
print(cmd)
subprocess.call(cmd)

