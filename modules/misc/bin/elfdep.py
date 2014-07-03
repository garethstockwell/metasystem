#!/usr/bin/env python

# elfdep

# Script which reads the headers of cross-compiled ELF binaries to determine
# static dependencies

'''

In ELF files, the dependencies are listed in the header under DT_NEEDED [CHECK]
tags.  These can be listed by using the objdump command line tool (here we are
using files located in $ANDROID_PRODUCT_OUT/system/lib as an example):

$ objdump -x libmedia.so | grep NEEDED
  NEEDED               libui.so
  NEEDED               liblog.so
  NEEDED               libcutils.so
...
(A total of 15 dependencies are listed)

At runtime, the loader attempts to resolve these dependencies by searching a
list of paths for files whose SONAME matches that of the dependency.

If the list of search paths is known, the result of this search - i.e. a tree of
resolved dependencies, and a list of resolution failures - can be computed.
Furthermore, in addition to asking 'on which libraries does X (directly or
indirectly) depend?', we can reverse the question: 'which files depend (directly
or indirectly) upon X?'.

Of course this doesn't show all runtime dependencies, only the static ones.  In
addition to dependencies which are listed in the ELF header, a program may
attempt to load libraries at runtime via the dlopen(3) system call.

This script computes static ELF dependency graphs, returning the results
either in text form or, via graphviz, as a pictorial representation.

$ elfdep.py libmedia.so
29 resolved forward dependencies:
libEGL.so
libGLESv2.so
libGLESv2_dbg.so
...

$ elfdep.py libmedia.so --depth 1
15 resolved forward dependencies:
libbinder.so
libc.so
libcamera_client.so
...

$ elfdep.py libmedia.so --reverse
38 reverse dependencies:
libFFTEm.so
libOpenMAXAL.so
libOpenSLES.so
...

$ elfdep.py libmedia.so --reverse --depth 1
18 reverse dependencies:
libSR_AudioIn.so
libandroid_runtime.so
libaudioeffect_jni.so
...

$ elfdep.py libmedia.so --graph out.png

'''


#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

from __future__ import print_function

import argparse
import logging
import os.path
import subprocess
import sys
import tempfile


#------------------------------------------------------------------------------
# Global constants
#------------------------------------------------------------------------------

LINE_WIDTH = 80


#------------------------------------------------------------------------------
# Classes
#------------------------------------------------------------------------------

class ReadelfParser(object):
    '''
    Class which uses the readelf tool to parse ELF headers.
    The NEEDED and SONAME fields are returned by corresponding accessor
    functions.
    '''
    def __init__(self):
        pass

    def get_needed(self, path):
        return self._get_field('NEEDED', path)

    def get_soname(self, path):
        result = self._get_field('SONAME', path)
        return result[0] if len(result) else ''

    def _parse(self, path):
        result = []
        try:
            # Note: following line only works on Unix
            fnull = open('/dev/null', 'w')
            output = subprocess.check_output(['readelf', '-d', path], stderr=fnull)
            result = output.split('\n')
        except:
            pass
        return result

    def _get_field(self, field, path):
        result = []
        output = self._parse(path)
        for line in output:
            if line.find('(' + field + ')') != -1:
                result.append(line.split()[4][1:-1])
        return result



class DependencyResolver(object):
    '''
    Class which attempts to resolve a list of dependencies by searching a list
    of paths.
    '''
    class Result(object):
        def __init__(self):
            self.resolved = []
            self.unresolved = []

    def __init__(self):
        self._paths = []
        self._parser = ReadelfParser()
        self._sonames = {}
        pass

    def add_path(self, path):
        abspath = os.path.abspath(path)
        self._paths.append(abspath)
        self._find_sofiles(abspath)

    def get_paths(self):
        return self._paths

    def resolve(self, path):
        result = DependencyResolver.Result()
        needed = self._parser.get_needed(path)
        for soname in needed:
            if soname in self._sonames.keys():
                result.resolved.append(self._sonames[soname])
            else:
                result.unresolved.append(soname)
        return result

    def _resolve(self, dependencies):
        soname = line.split()[4][1:-1]
        for path in self._paths:
            sofile = os.path.join(path, soname)
            if file_exists(sofile):
                result.resolved.append(sofile)
            else:
                result.unresolved.append(soname)

    def _find_sofiles(self, path):
        for filename in list_dir(path):
            soname = self._parser.get_soname(filename)
            if soname != '':
                if soname in self._sonames.keys():
                    sofile = self._sonames[soname]
                    raise IOError("Error: soname '{0}' appears in multiplesofiles({1}, {2}, ...)".format(
                              soname, sofile, filename))
                self._sonames[soname] = filename
                logging.debug("[SONAME] {0} -> {1}".format(soname, filename))


class NodeStore(object):
    '''
    Store of nodes, indexed by their paths.
    '''
    def __init__(self):
        self._nodes = {}

    def create_node(self, path):
        node = self.get_node(path)
        if not node:
            logging.debug("CREATE[" + os.path.basename(path) + "]")
            node = Node(path)
            self._nodes[path] = node
        return node

    def get_node(self, path):
        node = None
        if path in self._nodes.keys():
            node = self._nodes[path]
        return node

    def nodes(self):
        return self._nodes.values()


class DependencyTreeBuilder(object):
    '''
    Class which uses DependencyResolver to recursively build up a dependency
    graph for a given ELF file.
    '''
    def __init__(self):
        self._store = NodeStore()
        self._resolver = DependencyResolver()

    def store(self):
        return self._store

    def add_path(self, path):
        self._resolver.add_path(path)

    def get_paths(self):
        return self._resolver.get_paths()

    def dependency_tree(self, filename):
        root = self._store.create_node(filename)
        self._build_subtree(root)
        return root

    def _build_subtree(self, node):
        basename = os.path.basename(node.path)
        logging.debug("CHECK[" + basename + "]")
        dependencies = self._resolver.resolve(node.path)
        for path in dependencies.resolved:
            logging.debug("RESOLVED[" + basename + "] " + os.path.basename(path))
            child = self._store.get_node(path)
            if not child:
                child = self._store.create_node(path)
                self._build_subtree(child)
            node.children.append(child)
        for name in dependencies.unresolved:
            logging.debug("UNRESOLVED[" + basename + "] " + name)
            node.unresolved.append(name)


class Node(object):
    '''
    Node in the dependency graph.
    '''
    def __init__(self, path):
        self.path = path
        self.children = []
        self.unresolved = []

    def walk(self, visitor, maxdepth=0):
        self._walk(visitor, None, self, 0, maxdepth)

    def _walk(self, visitor, parent, node, depth, maxdepth):
        parent_path = os.path.basename(parent.path) if parent else ''
        logging.debug("[walk] {0} -> {1} depth({2},{3})".format(
            parent_path, os.path.basename(node.path), depth, maxdepth))
        if maxdepth == 0 or depth <= maxdepth:
            if visitor.travel(parent, node):
                logging.debug("[walk]   new")
                for child in node.children:
                    self._walk(visitor, node, child, depth+1, maxdepth)


class Visitor(object):
    '''
    Base class for visitors used to traverse the dependency graph.
    '''
    def __init__(self):
        self._travelled = set()

    def travel(self, src, dst):
        src_path = src.path if src else ''
        edge = src_path + ',' + dst.path
        if edge in self._travelled:
            return False
        else:
            self._travelled.add(edge)
            self._travel(src, dst)
            return True


class NodeCollector(Visitor):
    '''
    Visitor which collects a set of all the nodes which it visits.
    '''
    def __init__(self):
        Visitor.__init__(self)
        self._result = set()
        self._first = True

    def _travel(self, src, dst):
        if not self._first:
            self._result.add(dst)
        self._first = False

    def result(self):
        return self._result


class UnresolvedCollector(Visitor):
    '''
    Visitor which collects a set of unresolved dependencies for the nodes which
    it visits.
    '''
    def __init__(self):
        Visitor.__init__(self)
        self._result = set()

    def _travel(self, src, dst):
        for name in dst.unresolved:
            self._result.add(name)

    def result(self):
        return self._result


class Inverter(Visitor):
    '''
    Visitor which inverts the direction of all links in the dependency graph.
    '''
    def __init__(self):
        Visitor.__init__(self)
        self._store = NodeStore()
        self._result = None

    def _travel(self, src, dst):
        if src:
            new_dst = self._store.create_node(src.path)
            new_src = self._store.create_node(dst.path)
            new_src.children.append(new_dst)

    def get_node(self, path):
        return self._store.get_node(path)

    def nodes(self):
        return self._store.nodes()


class Graph(object):
    '''
    Class which uses the dot tool to generate a pictorial representation of the
    dependency graph.
    '''
    class GraphVisitor(Visitor):
        def __init__(self, gvfile, invert):
            Visitor.__init__(self)
            self._gvfile = gvfile
            self._invert = invert

        def _travel(self, src, dst):
            if self._invert:
                tmp = src
                src = dst
                dst = tmp
            src_path = os.path.basename(src.path) if src else ''
            dst_path = os.path.basename(dst.path) if dst else ''
            if src and dst:
                self._gvfile.write("    \"{0}\" -> \"{1}\";\n"
                            .format(src_path, dst_path))
            if not self._invert:
                for name in dst.unresolved:
                    self._gvfile.write("    \"{0}\" [color=red, style=filled];\n"
                                .format(name))
                    self._gvfile.write("    \"{0}\" -> \"{1}\";\n"
                                .format(dst_path, name))


    def __init__(self, args, invert=False):
        self._args = args
        self._open_file(args)
        self._write_header()
        self._visitor = Graph.GraphVisitor(self._gvfile, invert)

    def __del__(self):
        if self._visitor:
            self._write_footer()
            gvfilename = self._gvfile.name
            self._gvfile.flush()
            subprocess.call(['dot', gvfilename, '-T', 'png', '-o', self._args.graph])

    def add(self, root):
        root.walk(self._visitor, self._args.depth)

    def _open_file(self, args):
        delete = True
        if args.debug:
            delete = False
        self._gvfile = tempfile.NamedTemporaryFile(delete=delete)
        if args.debug:
            print("GraphViz file name = " + self._gvfile.name)

    def _write_header(self):
        self._gvfile.write("digraph elfdep {\n")
        self._gvfile.write("    node [color=lightblue2, style=filled];\n")

    def _write_footer(self):
        self._gvfile.write("}\n")


class ArgumentParser(argparse.ArgumentParser):
    def __init__(self):
        description = 'elfdep'
        epilog = '''
        Cross-compiled ELF binary static dependency tool
        '''
        version = '0.1'

        argparse.ArgumentParser.__init__(self,
                                         description = description,
                                         epilog = epilog)

        # Positional arguments
        self.add_argument('filename',
                          metavar='FILENAME',
                          help='ELF file')

        # Options
        self.add_argument('--debug',
                          dest='debug', default=False,
                          action='store_true',
                          help='show debugging output')
        self.add_argument('--full-paths',
                          dest='full_paths', default=False,
                          action='store_true',
                          help='show full paths')
        self.add_argument('-d', '--depth',
                          dest='depth',
                          default=0,
                          type=int,
                          help='maximum tree search depth')
        self.add_argument('-g', '--graph',
                          dest='graph',
                          help='graph filename')
        self.add_argument('-n', '--dry-run',
                          dest='dry_run', default=False,
                          action='store_true',
                          help='just show what would be done')
        self.add_argument('-r', '--reverse',
                          dest='reverse', default=False,
                          action='store_true',
                          help='reverse dependency search')
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
    print('Error:', message, file=sys.stderr)


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
    print('-' * LINE_WIDTH)
    print('Summary of options')
    print('-' * LINE_WIDTH)
    for key in initial_group:
        print(' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key))
    for key in sorted(list(set(keys) - set(initial_group))):
        print(' '+ key, ('.' * (rightcolpos - len(key) - 2)), getattr(args, key))
    print('-' * LINE_WIDTH)


def file_exists(filename):
    result = True
    try:
        with open(filename) as f: pass
    except IOError as e:
        result = False
    return result


def assert_file_exists(filename):
    if not file_exists(filename):
        raise IOError("Error: file '" + filename + "' not found\n")


def list_dir(path):
    result = []
    for entry in os.listdir(path):
        if not os.path.isdir(entry):
            result.append(os.path.join(path, entry))
    return result


def path_list(path_set, full_paths):
    if full_paths:
        return sorted(path_set)
    else:
        return sorted(map(os.path.basename, path_set))


#------------------------------------------------------------------------------
# Action functions
#------------------------------------------------------------------------------

def forward_search(builder, args):
    builder.add_path(os.path.dirname(args.filename))

    tree = builder.dependency_tree(args.filename)

    print("Search paths:")
    print("\n".join(builder.get_paths()))

    visitor = NodeCollector()
    tree.walk(visitor, args.depth)
    forward = map(lambda node: node.path, visitor.result())
    print("\n{0} resolved forward dependencies:".format(len(forward)))
    print("\n".join(path_list(forward, args.full_paths)))

    visitor = UnresolvedCollector()
    tree.walk(visitor, 0)
    unresolved = visitor.result()
    print("\n{0} unresolved forward dependencies:".format(len(unresolved)))
    print("\n".join(sorted(unresolved)))

    if args.graph:
        graph = Graph(args)
        graph.add(tree)


def reverse_search(builder, args):
    builder.add_path(os.path.dirname(args.filename))
    basename = os.path.basename(args.filename)

    inverter = Inverter()
    for path in builder.get_paths():
        for filename in list_dir(path):
            logging.debug('[REVERSE] ' + filename)
            fwd_tree = builder.dependency_tree(filename)
            fwd_tree.walk(inverter)
    tree = inverter.get_node(os.path.abspath(args.filename))

    if args.graph:
        graph = Graph(args, True)
        graph.add(tree)

    visitor = NodeCollector()
    tree.walk(visitor, args.depth)
    result = map(lambda node: node.path, visitor.result())
    print("\n{0} reverse dependencies:".format(len(result)))
    print("\n".join(path_list(result, args.full_paths)))


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args = parse_command_line()
if args.verbose:
    print_summary(args, ('filename'))
if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

assert_file_exists(args.filename)

builder = DependencyTreeBuilder()

if args.reverse:
    reverse_search(builder, args)
else:
    forward_search(builder, args)

