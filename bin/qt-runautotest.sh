#!/bin/sh

qt-runonphone.sh $* | grep -e TestLib -e Expected -e Actual -e Loc: --line-buffered

