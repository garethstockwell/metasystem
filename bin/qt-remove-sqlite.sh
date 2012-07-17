#!/bin/bash

# Script for removing sqlite from _template.pkg file

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

. `dirname "$0"`/qt-functions.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function PrintUsage {
    echo -e "Usage $0"
    echo -e "Options:"
    echo -e "  -h     Print help message"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

while getopts "h" option
do
    case "$option" in
        h)
            PrintUsage
            exit 0
            ;;
    esac
done

check_pwd_in_qt_build_dir

for pkg in `'ls' *_template.pkg`
do
	echo "PKG file: $pkg"
	tmp=$pkg.tmp
	rm -f $tmp
	mv $pkg $tmp
	cat $tmp | grep -iv sqlite > $pkg
	rm -f $tmp
done

