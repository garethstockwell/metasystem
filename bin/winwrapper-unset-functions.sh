#!/bin/bash

for function in `compgen -A function`
do
    unset -f $function
done

switch=/
test "$METASYSTEM_PLATFORM" == "mingw" && switch=//
cmd ${switch}c c:/apps/bin/cygwrapper.bat $*

