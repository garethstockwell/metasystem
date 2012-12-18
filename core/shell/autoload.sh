# autoload.sh

function autoload()
{
	local name=$1
	eval "$(echo "${name}() { _metasystem_autoload ${name} "\$@"; }")"
}

function _metasystem_autoload()
{
	local name=$1
	shift
	for path in $(path_split '\n' $FPATH); do
		local file=$path/$name
		if [[ -e $file ]]; then
			source_function $name $file
			break
		fi
	done
	eval "$(echo ${name} $@)"
}

