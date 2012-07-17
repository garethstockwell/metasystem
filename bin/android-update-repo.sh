#!/bin/bash

# android-update-repo

# Script for downloading and installing the latest version of repo
# Also patches it to use the appropriate transport protocol for the current
# firewall

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1
ARGUMENTS=''
REPO_DOWNLOAD_URL='https://dl-ssl.google.com/dl/googlesource/git-repo/repo'
REPO_INSTALL=$HOME/bin/repo


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_version=
opt_verbosity=normal
opt_dryrun=no
opt_protocol=http

for arg in $ARGUMENTS; do
	eval "arg_$arg="
done


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
function error()
{
	echo -e "\nError: $*"
	if [[ "$opt_dryrun" != yes ]]; then
		exit 1
	fi
}

function warn()
{
	echo "Warning: $*"
}

function usage_error()
{
	echo -e "Error: $*\n"
	print_usage
	exit 1
}

# Execute shell command; abort script if command fails
function execute()
{
	cmd="$*"
	[[ "$opt_verbosity" != silent ]] && echo -e "$cmd"
	if [[ "$opt_dryrun" != yes ]]; then
		$cmd
		r=$?
		[[ "$r" != 0 ]] && error Execution of \"$cmd\" failed: exit code $r
	fi
}

function print_rule()
{
	[[ "$opt_verbosity" != silent ]] && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [[ "$opt_verbosity" != silent ]]; then
		echo
		print_rule
		echo $*
		print_rule
	fi
}

function print_usage()
{
	cat << EOF
android-update-repo script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

EOF
}

function print_version()
{
	cat << EOF
android-update-repo script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $*
	for token in "$@"; do
		# If the previous option needs an argument, assign it.
		if [[ -n "$prev" ]]; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-h | -help | --help | -usage | --usage)
				opt_help=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				opt_verbosity=silent
				;;
			-v | -verbose | --verbose)
				opt_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				opt_dryrun=yes
				;;
			-V | -version | --version)
				opt_version=yes
				;;

			# Environment variables
			*=*)
				envvar=`expr "x$token" : 'x\([^=]*\)='`
				optarg=`echo "$optarg" | sed "s/'/'\\\\\\\\''/g"`
				eval "$envvar='$optarg'"
				export $envvar
				;;

			# Unrecognized options
			-*)
				warn "Unrecognized option '$token' ignored"
				;;

			# Normal arguments
			*)
				local arg_used=
				for arg in $ARGUMENTS; do
					if [[ -z `eval "echo \\$arg_$arg"` ]]; then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				[[ -z "$arg_used" ]] && warn "Additional argument '$token' ignored"
				;;
		esac
	done

	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $ARGUMENTS; do
		if [[ -z `eval "echo \\$arg_$arg"` ]]; then
			args_supplied=
			break
		fi
	done
	[[ -z "$args_supplied" ]] && usage_error 'Insufficient arguments provided'
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

repo download URL ....................... $REPO_DOWNLOAD_URL
repo install path ....................... $REPO_INSTALL

protocol ................................ $opt_protocol

EOF
	for arg in $ARGUMENTS; do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done
}

function download_repo()
{
	echo -e "\nDownloading repo ..."
	curl $REPO_DOWNLOAD_URL > $tmp_file 2>/dev/null
	echo
}

function get_version()
{
	local file=$1
	cat $file | grep ^VERSION |\
		awk '{ print $3,$4 }' |\
		sed -e 's/(//g' | sed -e 's/)//g' |\
		sed -e 's/,//g' | sed -e 's/ /./g'
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_command_line $args

test "$opt_help" == yes && print_usage && exit 0
test "$opt_version" == yes && print_version && exit 0
test "$opt_verbosity" != silent && print_summary

print_banner Starting execution

tmp_file=/tmp/repo-$$
download_repo
latest_version=$(get_version $tmp_file)

[[ -z $latest_version ]] && error "Download failed"

curr_version=
[[ -e $REPO_INSTALL ]] && curr_version=$(get_version $REPO_INSTALL)

[[ -n $curr_version ]] && echo "Current version: $curr_version"
echo "Latest version:  $latest_version"

if [[ $curr_version != $latest_version ]]; then
	echo -e "\nInstalling latest version ..."
	execute rm -f $REPO_INSTALL
	touch $REPO_INSTALL
	while IFS='\n' read line; do
		if [[ -n $(echo "$line" | grep ^REPO_URL) ]]; then
			if [[ $opt_dryrun != yes ]]; then
				echo "#$line" >> $REPO_INSTALL
				echo "# Using $opt_protocol protocol" >> $REPO_INSTALL
			fi
			line=$(echo "$line" | sed -e "s/https:/$opt_protocol:/" | sed -e "s/git:/$opt_protocol:/")
		fi
		[[ $opt_dryrun != yes ]] && echo "$line" >> $REPO_INSTALL
	done < $tmp_file
	execute chmod +x $REPO_INSTALL
fi

# Cleanup
rm -f $tmp_file

