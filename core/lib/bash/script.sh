# lib/bash/script.sh

# Intended to be included by non-interactive command-line scripts

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

# Command line parsing
unused_args=

# Set by command line
opt_dryrun=no
opt_help=
opt_verbosity=normal
opt_version=


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
	[[ "$opt_verbosity" != silent ]] && echo "$@"
	if [[ "$opt_dryrun" != yes ]]; then
		"$@"
		r=$?
		[[ "$r" != 0 ]] && error Execution of \"$@\" failed: exit code $r
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

function parse_standard_arguments()
{
	unused_args=
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

			*)
				[[ -n $unused_args ]] && unused_args="$unused_args "
				unused_args=$unused_args$token
				;;
		esac
	done
}

