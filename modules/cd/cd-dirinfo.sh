# cd-dirinfo.sh

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

function _metasystem_find_dirinfo()
{
	local dir=$1
	if [ ! -z "$dir" -a -e $dir/.metasystem-dirinfo ]
	then
		echo $dir/.metasystem-dirinfo
	else
		if [ "$dir" != "/" ]
		then
			_metasystem_find_dirinfo $(dirname $dir)
		fi
	fi
}

function _metasystem_cd()
{
	local init=
	if [[ "$1" == "-metasystem-init" ]]; then
		init=yes
	else
		builtin cd $*
	fi
	local file=$(_metasystem_find_dirinfo $PWD)
	local old_root=$METASYSTEM_DIRINFO_ROOT
	local root=
	[[ -n $file ]] && root=$(dirname $file)
	if [[ $old_root != $root ]]; then
		# .metasystem-dirinfo
		if [[ -z $init ]]; then
			if [[ -z $file ]]; then
				echo -e "\n${NAKED_YELLOW}Clearing directory metadata${NAKED_NO_COLOUR}"
			else
				echo -e "\n${NAKED_YELLOW}Parsing $root/.metasystem-dirinfo ...${NAKED_NO_COLOUR}"
			fi
		fi
		METASYSTEM_DIRINFO_LABEL=
		export METASYSTEM_DIRINFO_ROOT=$root
		local shell_script=
		if [[ -z $file ]]; then
			metasystem-dirinfo.py
			shell_script=~/.metasystem-dirinfo.sh
		else
			metasystem-dirinfo.py -f $file
			shell_script=${file}.sh
		fi
		. ${shell_script}

		# smartcd compatibility layer
		local bash_enter=~/.smartcd/scripts/$root/bash_enter
		if [[ -e $bash_enter ]]; then
			echo -e "\n${NAKED_YELLOW}Running $bash_enter ...${NAKED_NO_COLOUR}"
			while read line; do
				line=${line//__PATH__/$root}
				eval "$line"
			done < $bash_enter
		fi

		# epocroot
		if [[ -n $METASYSTEM_OPT_SYMBIAN ]]; then
			local epocroot_set=`cat ${shell_script} | grep 'export EPOCROOT'`
			if [[ -z $epocroot_set ]]; then
				_metasystem_check_epocroot
			else
				[[ -n $EPOCROOT ]] && export PATH=$(path_prepend_epoc)
			fi
		fi
	fi
}


#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Exported functions
#------------------------------------------------------------------------------

