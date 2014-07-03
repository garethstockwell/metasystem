#!/usr/bin/env python

from __future__ import print_function

import os
import sys

if len(sys.argv) > 1:
    filename = sys.argv[1]
    f = open(filename, 'r')
    content = f.read()
    f.close()
    os.remove(filename)
    f = open(filename, 'w')
    f.write(content.replace('\n\n', '\n'))
else:
    content = sys.stdin.read()
    print(content.replace('\n\n', '\n'))

