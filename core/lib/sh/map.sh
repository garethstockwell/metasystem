# lib/bash/map.sh

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

# Hash functions
# http://stackoverflow.com/questions/688849/associative-arrays-in-shell-scripts

if [ "$METASYSTEM_BASH_ASSOC_ARRAY" == "yes" ]
then

function map_clear()
{
	local mapName=_METASYSTEM_HASH_$1
	#echo "map_clear(assoc) $mapName" >&2
	for key in $(eval echo \$\{!$mapName[@]\})
	do
		eval $mapName\[$key\]=
	done
}

function map_put()
{
	if [ "$#" != 3 ]; then exit 1; fi
	local mapName=_METASYSTEM_HASH_$1
	local key=$2
	local value=${3// /:SP:}
	#echo "map_put(assoc) $mapName[$key]=$value" >&2
	eval $mapName\[$key\]=$value
}

function map_get()
{
	local mapName=_METASYSTEM_HASH_$1
	local key=$2
	#echo "map_get(assoc) $mapName[$key]" `eval echo \$\{$mapName\[$key\]\}` >&2
	eval echo \${$mapName[$key]}
}

else # METASYSTEM_BASH_ASSOC_ARRAY

function map_clear()
{
	local mapName=_METASYSTEM_HASH_$1
	#echo "map_clear(slow) $mapName"
	eval $mapName=''
}

function map_put()
{
	if [ "$#" != 3 ]; then exit 1; fi
	local mapName=_METASYSTEM_HASH_$1
	local key=$2
	local value=${3// /:SP:}
	#echo "map_put(slow) $mapName[$key]=$value" >&2
	local map=
	eval map="\"\$$mapName\""
	map="`echo "$map" | sed -e "s/$key=\".*\"//g"` $key=$value"
	eval $mapName="\"$map\""
}

function map_get()
{
	local mapName=_METASYSTEM_HASH_$1
	local key=$2
	local valueFound="false"
	local map=
	eval map=\$$mapName
	local value=
	if [ ! -z "$map" ]
	then
		local keyValuePair=
		for keyValuePair in ${map};
		do
			case "$keyValuePair" in
			$key=*)
				value=`echo "$keyValuePair" | sed -e 's/^[^=]*=//'`
				valueFound="true"
			esac
			if [ "$valueFound" == "true" ]; then break; fi
		done
	fi
	local result=${value//:SP:/ }
	#echo "map_get(slow) $mapName[$key] [$result]" >&2
	echo $result
}

fi # METASYSTEM_BASH_ASSOC_ARRAY

function _metasystem_parse_kvf()
{
	local mapName=$1
	local file=$2
	map_clear $mapName
	if [ ! -z "$file" -a -e "$file" ]
	then
		local key=
		local value=
		while read key value
		do
			if [ ! -z "$key" ]
			then
				map_put $mapName $key $value
			fi
		done < $file
	fi
}

