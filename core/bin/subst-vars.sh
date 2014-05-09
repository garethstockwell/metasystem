#!/usr/bin/env bash

# Script for installing a file, substituting in environment variable values
#
# Given an input file with the following content:
#	foo${X}bar
#
# If the script is run with X=123, the output file contents will be:
#	foo123bar

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

DEFAULT_START=$
DEFAULT_OPEN={
DEFAULT_CLOSE=}


#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------

force=
help=
verbose=
dryrun=
src=
dest=

opt_start=
opt_open=
opt_close=


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

  --start CHAR            start character (default: $DEFAULT_START)
  --open CHAR             open character (default: $DEFAULT_OPEN)
  --close CHAR            close character (default: $DEFAULT_CLOSE)

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
			--start)
				prev=opt_start
				;;
			--open)
				prev=opt_open
				;;
			--close)
				prev=opt_close
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

	[[ -n $opt_start ]] || opt_start=$DEFAULT_START
	[[ -n $opt_open ]] || opt_open=$DEFAULT_OPEN
	[[ -n $opt_close ]] || opt_close=$DEFAULT_CLOSE
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
			while(match(\$0, \"[${opt_start}]${opt_open}[^${opt_close}]*${opt_close}\")) {
				var = substr(\$0, RSTART+2, RLENGTH-3);
				gsub(\"[${opt_start}]${opt_open}\"var\"${opt_close}\", ENVIRON[var])
			}
		}1'"

test -n "$dest" && cmd="$cmd > $dest"

test "$verbose" == yes && echo $cmd

if [[ -z "$dryrun" ]]; then
	eval $cmd
	if [[ $METASYSTEM_OS == mac ]]; then
		perm=$(stat -f %p $src)
	else
		perm=$(stat -c %a $src)
	fi
	chmod $perm $dest
fi

