#!/bin/bash

# git-change-author

# TODO: use -d option to redirect temporary files to tmpfs, for increased speed

# Note: you can check the results of the change with e.g.
#	git log --format='%an %ae %cn %ce'

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
option_help=
option_version=
option_verbosity=normal
option_dryrun=no
option_force=no
option_debug=no
option_old_author_email=
option_old_committer_email=
option_author_name=
option_author_email=
option_committer_name=
option_committer_email=

for arg in $ARGUMENTS; do eval "arg_$arg="; done

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Print an error message and exit
# First argument is an error code
function error()
{
	code=$1
	shift
	echo "Error $code: $*"
	if [ "$option_dryrun" != yes ]
	then
		exit $code
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
	test "$option_verbosity" != silent && echo -e "\n$cmd"
	if [ "$option_dryrun" != yes ]
	then
		$cmd
		r=$?
		if [ "$r" != 0 ]
		then
			error $r Execution of '$cmd' failed
		fi
	fi
}

function print_rule()
{
	test "$option_verbosity" != silent && \
		echo '----------------------------------------------------------------------'
}

function print_banner()
{
	if [ "$option_verbosity" != silent ]
	then
		echo
		print_rule
		echo $*
		print_rule
	fi
}

function print_usage()
{
	cat << EOF
git-change-author script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit
    -f, --force             Pass --force to 'git filter-branch'
    -d, --debug             Debug this script

    --old-email             Old email (apply to both author and committer)
    --old-author-email      Old author email
    --old-committer-email   Old committer email

    --name                  New name (apply to both author and committer)
    --author-name           New author name
    --committer-name        New committer name
    --email                 New email (apply to both author and committer)
    --author-email          New author email
    --committer-email       New committer email
EOF
}

function print_version()
{
	cat << EOF
git-change-author script version $SCRIPT_VERSION
EOF
}

function parse_command_line()
{
	eval set -- $*
	for token in "$@"
	do
		# If the previous option needs an argument, assign it.
		if test -n "$prev"; then
			eval "$prev=\$token"
			prev=
			continue
		fi

		optarg=`expr "x$token" : 'x[^=]*=\(.*\)'`

		case $token in
			# Options
			-h | -help | --help | -usage | --usage)
				option_help=yes
				;;
			-q | -quiet | --quiet | -silent | --silent)
				option_verbosity=silent
				;;
			-v | -verbose | --verbose)
				option_verbosity=verbose
				;;
			-n | -dry-run | --dry-run | -dryrun | --dry-run)
				option_dryrun=yes
				;;
			-V | -version | --version)
				option_version=yes
				;;
			-f | -force | --force)
				option_force=yes
				;;
			-d | -debug | --debug)
				option_debug=yes
				;;

			--old-email)
				prev=option_old_email
				;;
			--old-email=*)
				option_old_email=$optarg
				;;

			--old-author-email)
				prev=option_old_author_email
				;;
			--old-author-email=*)
				option_old_author_email=$optarg
				;;

			--old-committer-email)
				prev=option_old_committer_email
				;;
			--old-committer-email=*)
				option_old_committer_email=$optarg
				;;

			--new-name | --name)
				prev=option_name
				;;
			--new-name=* | --name=*)
				option_name=$optarg
				;;

			--new-author-name | --author-name)
				prev=option_author_name
				;;
			--new-author-name=* | --author-name=*)
				option_author_name=$optarg
				;;

			--new-committer-name | --committer-name)
				prev=option_committer_name
				;;
			--new-committer-name=* | --committer-name=*)
				option_committer_name=$optarg
				;;

			--new-email | --email)
				prev=option_email
				;;
			--new-email=* | --email=*)
				option_email=$optarg
				;;

			--new-author-email | --author-email)
				prev=option_author_email
				;;
			--new-author-email=* | --author-email=*)
				option_author_email=$optarg
				;;

			--new-committer-email | --committer-email)
				prev=option_committer_email
				;;
			--new-committer-email=* | --committer-email=*)
				option_committer_email=$optarg
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
				for arg in $ARGUMENTS
				do
					if [ -z `eval "echo \\$arg_$arg"` ]
					then
						eval "arg_$arg=$token"
						arg_used=1
						break
					fi
				done
				test -z "$arg_used" && warn "Additional argument '$token' ignored"
				;;
		esac
	done

	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $ARGUMENTS
	do
		if [ -z `eval "echo \\$arg_$arg"` ]
		then
			args_supplied=
			break
		fi
	done
	test -z "$args_supplied" && usage_error 'Insufficient arguments provided'

	if [ ! -z "$option_old_email" ]
	then
		option_old_author_email=$option_old_email
		option_old_committer_email=$option_old_email
	fi

	if [ ! -z "$option_email" ]
	then
		option_author_email=$option_email
		option_committer_email=$option_email
	fi

	if [ ! -z "$option_name" ]
	then
		option_author_name=$option_name
		option_committer_name=$option_name
	fi
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $option_verbosity
Dry run ................................. $option_dryrun

EOF
	for arg in $ARGUMENTS
	do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done

	cat << EOF
force ................................... $option_force
debug ................................... $option_debug

old author email ........................ $option_old_author_email
old committer email ..................... $option_old_committer_email

new author name ......................... $option_author_name
new author email ........................ $option_author_email
new committer name ...................... $option_committer_name
new committer email ..................... $option_committer_email

EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"
do
	args="$args \"$arg\""
done
parse_command_line $args

test "$option_help" == yes && print_usage && exit 0
test "$option_version" == yes && print_version && exit 0
test "$option_verbosity" != silent && print_summary

if [ ! -z "$option_old_author_email" ]
then
	if [ -z "$option_author_email" ]
	then
		echo "Error: new author email must be provided"
		exit 1
	fi
fi

if [ ! -z "$option_old_committer_email" ]
then
	if [ -z "$option_committer_email" ]
	then
		echo "Error: new committer email must be provided"
		exit 1
	fi
fi

script=.git-change-author.sh
test -e $script && execute rm -f $script

force=
test "$option_force" == "yes" && force=' --force'

cat >> $script << EOF
git filter-branch$force --env-filter '

EOF

cat >> $script << EOF
an="\$GIT_AUTHOR_NAME"
am="\$GIT_AUTHOR_EMAIL"
cn="\$GIT_COMMITTER_NAME"
cm="\$GIT_COMMITTER_EMAIL"
EOF

test "$option_debug" == "yes" && cat >> $script << EOF

echo "\n"
echo "old GIT_AUTHOR_NAME=\$an"
echo "old GIT_AUTHOR_EMAIL=\$am"
echo "old GIT_COMMITTER_NAME=\$cn"
echo "old GIT_COMMITTER_EMAIL=\$cm"
echo
EOF

if [ -z "$option_old_author_email" -a -z "$option_old_committer_email" ]
then
	if [ ! -z "$option_author_name" ]
	then
		cat >> $script << EOF

an="$option_author_name"
EOF
	fi

	if [ ! -z "$option_author_email" ]
	then
		cat >> $script << EOF

am="$option_author_email"
EOF
	fi
	if [ ! -z "$option_committer_name" ]
	then
		cat >> $script << EOF

cn="$option_committer_name"
EOF
	fi

	if [ ! -z "$option_committer_email" ]
	then
		cat >> $script << EOF

cm="$option_committer_email"
EOF
	fi

else

if [ ! -z "$option_old_author_email" ]
then
	cat >> $script << EOF

if [ "\$GIT_AUTHOR_EMAIL" == "$option_old_author_email" ]
then
EOF
if [ ! -z "$option_author_name" ]
then
	cat >> $script << EOF
    an="$option_author_name"
EOF
fi
	cat >> $script << EOF
    am="$option_author_email"
fi
EOF
fi

if [ ! -z "$option_old_committer_email" ]
then
	cat >> $script << EOF

if [ "\$GIT_COMMITTER_EMAIL" == "$option_old_committer_email" ]
then
EOF
if [ ! -z "$option_committer_name" ]
then
	cat >> $script << EOF
    cn="$option_committer_name"
EOF
fi
	cat >> $script << EOF
    cm="$option_committer_email"
fi
EOF
fi

fi

test "$option_debug" == "yes" && cat >> $script << EOF

echo "new GIT_AUTHOR_NAME=\$an"
echo "new GIT_AUTHOR_EMAIL=\$am"
echo "new GIT_COMMITTER_NAME=\$cn"
echo "new GIT_COMMITTER_EMAIL=\$cm"
echo
EOF

cat >> $script << EOF

export GIT_AUTHOR_NAME="\$an"
export GIT_AUTHOR_EMAIL="\$am"
export GIT_COMMITTER_NAME="\$cn"
export GIT_COMMITTER_EMAIL="\$cm"
EOF

cat >> $script << EOF
'
EOF

execute chmod +x $script

execute $PWD/$script

test "$option_debug" == "no" && execute rm -f $script

if [ "$option_dryrun" == "no" ]
then
	echo -e "\nRewrite complete\n"
	git log --reverse --format='%h %ci "%an" %ae "%cn" %ce'
fi

