# autoload.sh

#------------------------------------------------------------------------------
# BASH compatibility layer
#------------------------------------------------------------------------------

if [[ -n $BASH_VERSION ]]; then

function autoload()
{
	local name=$1
	eval "$(echo "${name}() { _metasystem_autoload ${name} "\$@"; }")"
}

function _metasystem_autoload()
{
	local name=$1
	shift
	for path in $(echo $FPATH | sed -e 's/:/\n/g'); do
		local file=$path/$name
		if [[ -e $file ]]; then
			eval "$(echo "${name}() {"; cat ${file}; echo '}' )"
			break
		fi
	done
	eval "$(echo ${name} $@)"
}

export -f autoload
export -f _metasystem_autoload

fi


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_autoload_all()
{
	for dir in $METASYSTEM_CORE_LIB/autoload \
			   $METASYSTEM_CORE_LIB/autoload/$METASYSTEM_PLATFORM; do
		export FPATH=$dir:$FPATH
		for file in $(find $dir -type f 2>/dev/null); do
			autoload $(basename $file)
		done
	done
}

