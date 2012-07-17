#!/bin/bash

# Script for building (parts I care about from) the Qt5 alpha release
#
# Requires QT_SOURCE_DIR environment variable to be set
#
# For shadow building:
# If QT_INSTALL_DIR is empty, it is set to $QT_BUILD_DIR/../install
# QT_BUILD_DIR and QT_INSTALL_DIR will be removed and recreated, if already
# present before this script is run

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

MODULES="qtdeclarative qtjsbackend qtmultimedia qtxmlpatterns"
SOURCE_ARCHIVE=~/Downloads/qt-everywhere-opensource-src-5.0.0-alpha.tar.bz2


#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

function error()
{
    echo "Error: $*"
    exit 1
}

# Echo a command and then execute it
function execute()
{
	echo $*
	$*
}

function number_of_processors()
{
    local result=$NUMBER_OF_PROCESSORS
    if [ -z "$result" -a -e /proc/cpuinfo ]
    then
        result=`cat /proc/cpuinfo | grep processor | wc -l`
    fi
    echo $result
}


#------------------------------------------------------------------------------
# Build functions
#------------------------------------------------------------------------------

function shadow_build()
{
	test -z "$QT_INSTALL_DIR" && QT_INSTALL_DIR=$QT_BUILD_DIR/../install

	# Sanity checks
	test -z "$QT_BUILD_DIR" && error "QT_BUILD_DIR is empty"

	# Echo environment variables
	echo "QT_SOURCE_DIR .................... $QT_SOURCE_DIR"
	echo "QT_BUILD_DIR ..................... $QT_BUILD_DIR"
	echo "QT_INSTALL_DIR ................... $QT_INSTALL_DIR"
	echo

	# Create build and install dirs
	execute cd ~
	execute rm -rf $QT_BUILD_DIR
	execute mkdir -p $QT_BUILD_DIR
	execute rm -rf $QT_INSTALL_DIR
	execute mkdir -p $QT_INSTALL_DIR

	# Configure Qt
	execute cd $QT_BUILD_DIR
	execute $QT_SOURCE_DIR/configure \
		-prefix $QT_INSTALL_DIR \
		-opensource -confirm-license \
		-nomake tests \
		-release

	# Create submodule build directories
	for module in $MODULES
	do
		execute make $module/Makefile
	done

	# build script does not support shadow builds
	execute cp $QT_SOURCE_DIR/build.dependencies .

	# Build Qt
	execute $QT_SOURCE_DIR/build -j $MAKEJOBS
}

function unpack_source()
{
	execute cd ~
	execute rm -rf $QT_SOURCE_DIR
	execute mkdir -p $QT_SOURCE_DIR

	execute cd $QT_SOURCE_DIR
	execute tar xjvf $SOURCE_ARCHIVE
	execute mv qt-everywhere-opensource-src-5.0.0/* .
	execute mv qt-everywhere-opensource-src-5.0.0/.* .
	execute rmdir qt-everywhere-opensource-src-5.0.0
}

function in_source_build()
{
	# Echo environment variables
	echo "QT_SOURCE_DIR .................... $QT_SOURCE_DIR"
	echo

	# Configure Qt
	execute cd $QT_SOURCE_DIR
	execute ./configure \
		-prefix $QT_SOURCE_DIR/qtbase \
		-opensource -confirm-license \
		-nomake tests \
		-release

	# Build Qt
	execute $QT_SOURCE_DIR/build -j $MAKEJOBS $MODULES
}


#------------------------------------------------------------------------------
# Execution starts here
#------------------------------------------------------------------------------

# Sanity checks
test -z "$QT_SOURCE_DIR" && error "QT_SOURCE_DIR is empty"
test -e "$QT_SOURCE_DIR" || error "QT_SOURCE_DIR $QT_SOURCE_DIR not found"

MAKEJOBS=$(number_of_processors)

# Parallelise make jobs run by configure
export MAKEFLAGS=-j$MAKEJOBS

#unpack_source

#shadow_build
in_source_build

