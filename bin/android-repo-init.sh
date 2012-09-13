#!/bin/bash

# android-repo-init

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

SCRIPT_VERSION=0.1

# Arguments
ARGUMENTS=''

DEFAULT_NUMJOBS=8


#------------------------------------------------------------------------------
# Variables populated by command-line
#------------------------------------------------------------------------------

# Options
opt_help=
opt_force=no
opt_version=
opt_verbosity=normal
opt_dryrun=no

opt_clean=no
opt_reference=
opt_manifest_url=
opt_manifest_branch=
opt_local_manifest=
opt_repo_url=
opt_numjobs=
opt_sync=no

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
	[[ "$opt_verbosity" != silent ]] && echo "$cmd"
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
android-repo-init script

Usage: $0 [options] $ARGUMENTS

Default values for options are specified in brackets.

Options:
    -h, --help, --usage     Display this help and exit
    -f, --force             Remove existing files
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit

    --reference PATH        Reference

    -u, --url URL           Manifest URL
    -b, --branch REVISION   Manifest branch or revision

    --repo-url URL          Repo URL

    -l, --local MANIFEST    Local manifest

    -j, --jobs N            Number of jobs (default $DEFAULT_NUMJOBS)

    --sync                  Sync
    --no-sync               Do not sync

EOF
}

function print_version()
{
	cat << EOF
android-repo-init script version $SCRIPT_VERSION
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
			-f | -force | --force)
				opt_force=yes
				;;
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

			-c | -clean | --clean)
				opt_clean=yes
				;;

			-reference | --reference)
				prev=opt_reference
				;;
			-reference=* | --reference=*)
				opt_reference=$optarg
				;;

			-u | -url | --url)
				prev=opt_manifest_url
				;;
			-u=* | -url=* | --url=*)
				opt_manifest_url=$optarg
				;;

			-b | -branch | --branch)
				prev=opt_manifest_branch
				;;
			-b=* | -branch=* | --branch=*)
				opt_manifest_branch=$optarg
				;;

			-repo-url | --repo-url)
				prev=opt_repo_url
				;;
			-repo-url=* | --repo-url=*)
				opt_repo_url=$optarg
				;;

			-l | -local | --local)
				prev=opt_local_manifest
				;;
			-l=* | -local=* | --local=*)
				opt_local_manifest=$optarg
				;;

			-j | -jobs | --jobs)
				prev=opt_numjobs
				;;
			-j=* | -jobs=* | --jobs=*)
				opt_numjobs=$optarg
				;;

			-sync | --sync)
				opt_sync=yes
				;;
			-no-sync | --no-sync)
				opt_sync=no
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

	# Apply defaults
	[[ -z $opt_numjobs ]] && opt_numjobs=$DEFAULT_NUMJOBS
}

function print_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Dry run ................................. $opt_dryrun
Force ................................... $opt_force
Verbosity ............................... $opt_verbosity

Clean ................................... $opt_clean
Reference ............................... $opt_reference
Manifest URL ............................ $opt_manifest_url
Manifest branch ......................... $opt_manifest_branch
Repo URL ................................ $opt_repo_url
Local manifest .......................... $opt_local_manifest
Number of jobs .......................... $opt_numjobs
Sync .................................... $opt_repo_sync

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


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

args=
for arg in "$@"; do
	args="$args \"$arg\""
done

parse_command_line $args

[[ $opt_help == yes ]] && print_usage && exit 0
[[ $opt_version == yes ]] && print_version && exit 0
[[ $opt_verbosity != silent ]] && print_summary

print_banner Starting execution
echo

[[ -z $ANDROID_SRC ]] && error ANDROID_SRC is not set

[[ $opt_clean == yes && -d $ANDROID_SRC ]] && execute rm -f $ANDROID_SRC
[[ ! -d $ANDROID_SRC ]] && execute mkdir -p $ANDROID_SRC
execute cd $ANDROID_SRC

if [[ -n $opt_manifest_url ]]; then
	[[ -z $opt_manifest_branch ]] && error No manifest branch specified
	cmd="repo init"
	[[ -n $opt_reference ]] && cmd="$cmd --reference $opt_reference"
	cmd="$cmd -u $opt_manifest_url -b $opt_manifest_branch"
	[[ -n $opt_repo_url ]] && cmd="$cmd --repo-url $opt_repo_url"
	execute $cmd
fi

local_manifest=$ANDROID_SRC/.repo/local_manifest.xml

if [[ -e $local_manifest ]]; then
	[[ $opt_force != yes ]] && error "Destination file '$local_manifest' exists.  Use --force to remove"
	execute rm -f $local_manifest
fi

if [[ -n $opt_local_manifest ]]; then
	[[ ! -e $opt_local_manifest ]] && error "Manifest '$opt_local_manifest' not found"
	execute cp $opt_local_manifest $local_manifest
fi

[[ $opt_sync == yes ]] &&\
	execute android-repo-sync.sh -j $opt_numjobs -q

print_banner Done

