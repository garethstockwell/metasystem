#!/usr/bin/env python

# Script for testing Console module

import os
import sys

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
import Console

def print_break():
    sys.stdout.write("\n")
    sys.stderr.write("\n")

sys.stdout.write("out-default-default\n")
sys.stderr.write("err-default-default\n")

print_break()

sys.stdout.state.set_fg(Console.Color.RED)
sys.stdout.write("out-red-default\n")
sys.stderr.write("err-default-default\n")

print_break()

sys.stdout.state.set_bg(Console.Color.WHITE)
sys.stdout.write("out-red-white\n")
sys.stderr.write("err-default-default\n")

print_break()

sys.stderr.state.set_fg(Console.Color.BLUE)
sys.stdout.write("out-red-white\n")
sys.stderr.write("err-blue-default\n")

print_break()

sys.stderr.state.set_bg(Console.Color.YELLOW)
sys.stdout.write("out-red-white\n")
sys.stderr.write("err-blue-yellow\n")

print_break()

