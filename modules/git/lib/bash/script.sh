# script.sh

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

# Command line parsing
unused_args=
extra_args=

# Set by command line
opt_dryrun=no
opt_help=
opt_verbosity=normal
opt_version=

# Positional arguments
for arg in $SCRIPT_ARGS; do
	eval "arg_$arg="
done


#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

USAGE_HEADER="$SCRIPT_NAME

Usage: $0 [options] $SCRIPT_ARGS

Default values for options are specified in brackets."

USAGE_STANDARD_OPTIONS="Options:
    -h, --help, --usage     Display this help and exit
    -n, --dry-run           Do not execute any shell commands
    -q, --quiet, --silent   Suppress output
    -v, --verbose           Verbose output
    -V, --version           Display version information and exit"


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
	[[ "$opt_verbosity" == verbose ]] && echo "$@"
	if [[ "$opt_dryrun" != yes ]]; then
		"$@"
		r=$?
		[[ "$r" != 0 ]] && error Execution of \"$@\" failed: exit code $r
	fi
	return $r
}

function check_error_code()
{
	local r=$?
	if [[ $opt_dryrun != yes ]]; then
		if [[ $r != 0 ]]; then
			exit $r
		fi
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
				unused_args="$unused_args\"$token\""
				;;
		esac
	done
}

function print_version()
{
	cat << EOF
$SCRIPT_NAME version $SCRIPT_VERSION
EOF
}

function handle_arg()
{
	local token=$1
	local arg_used=
	local arg=
	for arg in $SCRIPT_ARGS; do
		if [[ -z `eval "echo \\$arg_$arg"` ]]; then
			eval "arg_$arg=$token"
			arg_used=1
			break
		fi
	done
	if [[ -z "$arg_used" ]]; then
		extra_args="$extra_args \"$token\""
		if [[ -z $SCRIPT_VAR_ARGS ]]; then
			warn "Additional argument '$token' ignored"
		fi
	fi
}

function check_sufficient_args()
{
	# Check that required arguments have been provided
	# TODO: we only really need to check the last argument: is there a neater way,
	# other than using a loop?
	local args_supplied=1
	for arg in $SCRIPT_ARGS; do
		if [[ -z `eval "echo \\$arg_$arg"` ]]; then
			args_supplied=
			break
		fi
	done
	[[ -z "$args_supplied" ]] && usage_error 'Insufficient arguments provided'
}

function print_standard_summary()
{
	print_banner 'Summary'
	local total_num_dots=40
	cat << EOF

Verbosity ............................... $opt_verbosity
Dry run ................................. $opt_dryrun

EOF
	for arg in $SCRIPT_ARGS; do
		local arg_len=${#arg}
		let num_dots=total_num_dots-arg_len
		local value=`eval "echo \\$arg_$arg"`
		echo -n "$arg "
		awk "BEGIN{for(c=0;c<$num_dots;c++) printf \".\"}"
		echo " $value"
	done
}

function script_preamble()
{
	if [[ $opt_help == yes ]]; then
		print_usage
		exit 0
	fi

	if [[ $opt_version == yes ]]; then
		print_version
		exit 0
	fi

	if [[ $opt_verbosity == verbose ]]; then
		print_summary
	fi
}

