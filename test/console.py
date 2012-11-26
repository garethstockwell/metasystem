#!/usr/bin/env python

# Script for testing Console module

import os
import sys

sys.path.append(os.path.join(sys.path[0], '../lib/python'))
import Console

def print_break():
    Console.stdout.write("\n")
    Console.stderr.write("\n")

Console.stdout.write("out-default-default\n")
Console.stderr.write("err-default-default\n")

print_break()

Console.stdout.set_fg(Console.RED)
Console.stdout.write("out-red-default\n")
Console.stderr.write("err-default-default\n")

print_break()

Console.stdout.set_bg(Console.WHITE)
Console.stdout.write("out-red-white\n")
Console.stderr.write("err-default-default\n")

print_break()

Console.stderr.set_fg(Console.BLUE)
Console.stdout.write("out-red-white\n")
Console.stderr.write("err-blue-default\n")

print_break()

Console.stderr.set_bg(Console.YELLOW)
Console.stdout.write("out-red-white\n")
Console.stderr.write("err-blue-yellow\n")

print_break()

