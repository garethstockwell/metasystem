#!/bin/bash

# Script for installing a file, substituting in environment variable values
#
# Given an input file with the following content:
#	foo${X}bar
#
# If the script is run with X=123, the output file contents will be:
#	foo123bar

#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

force=
help=
verbose=
dryrun=
src=
dest=

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function print_usage()
{
	cat << EOF
Script for installing config files

Usage: $0 [options] [INPUT]

Options:
  -h, --help              display this help and exit
  -f, --force             overwrite OUTPUT if it exists
  -o, --output OUTPUT     output file
  -v, --verbose           verbose output
  -n, --dry-run           don't execute

If INPUT is omitted, input is read from STDIN.
If OUTPUT is omitted, output is written to STDOUT.

EOF
}

function parse_command_line()
{
	for option
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"; then
			eval "$prev=\$option"
			prev=
			continue
		fi

		optarg=`expr "x$option" : 'x[^=]*=\(.*\)'`

		case $option in
			-f | -force | --force)
				force=yes
				;;
			-h | -help | --help)
				help=yes
				;;
			-n | --dry-run)
				dryrun=yes
				;;
			-o | -output | --output)
				prev=dest
				;;
			--output=*)
				dest=$optarg
				;;
			-v | --verbose)
				verbose=yes
				;;
			*=*)
				local key=`expr "x$option" : 'x\([^=]*\)='`
				local value=`echo "$optarg" | sed "s/'/'\\\\\\\\''/g"`
				eval "$key='$value'"
				;;
			*)
				if [ -z "$src" ]
				then
					src=$option
				else
					if [ -z "$dest" ]
					then
						dest=$option
					else
						echo "Warning: argument $option ignored"
					fi
				fi
				;;
		esac
	done
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

parse_command_line $*

test "$help" == yes && print_usage && exit 0

test "$verbose" == yes && echo -e "Source = $src\nDestination = $dest"

if [ ! -z "$src" -a ! -e "$src" ]
then
	echo "Error: input file '$src' not found"
	exit 1
fi

if [ ! -z "$dest" -a -e "$dest" ]
then
	if [ -z "$force" ]
	then
		echo "Error: output file '$dest' exists: use -f to force removal"
		exit 1
	fi
	cmd="rm -rf $dest"
	test "$verbose" == yes && echo $cmd
	test -z "$dryrun" && eval $cmd
fi

cmd=
test -n "$dest" && cmd="rm -f $dest && "
cmd="$cmd
	 cat $src |
		awk '{
			while(match(\$0, \"[$]{[^}]*}\")) {
				var = substr(\$0, RSTART+2, RLENGTH-3);
				gsub(\"[$]{\"var\"}\", ENVIRON[var])
			}
		}1'"
test -n "$dest" && cmd="$cmd > $dest"

test "$verbose" == yes && echo $cmd

test -z "$dryrun" && eval $cmd

