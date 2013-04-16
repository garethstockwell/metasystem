# cd-smartcd.sh
#
# Integration layer for smartcd (https://github.com/cxreg/smartcd)

#------------------------------------------------------------------------------
# Functions required by smartcd_install
#------------------------------------------------------------------------------

function do_smartcd_install_templates()
{
	local src_dir=$1
	local dst_dir=~/.smartcd/templates
	if [[ -e $src_dir ]]; then
		[[ ! -d $dst_dir ]] && mkdir -p $dst_dir
		for name in `'ls' $src_dir`; do
			echo "Installing smartcd template '$name' ..."
			rm -f $dst_dir/$name
			cp $src_dir/$name $dst_dir
		done
	fi
}

function smartcd_install_templates()
{
	do_smartcd_install_templates $METASYSTEM_CD_ROOT/templates
	do_smartcd_install_templates $METASYSTEM_LOCAL_ROOT/templates/smartcd
}


#------------------------------------------------------------------------------
# Dependency check
#------------------------------------------------------------------------------

smartcd_lib=$HOME/.smartcd/lib/core/smartcd
[[ -e $smartcd_lib ]] && source $smartcd_lib
unset smartcd_lib

func_exists smartcd
if [[ $? != 0 ]]; then
	function smartcd_install()
	{
		local smartcd_dir=$METASYSTEM_ROOT/../smartcd
		if [[ -d $smartcd_dir ]]; then
			echo "$smartcd_dir already exists - skipping clone"
		else
			echo "Cloning smartcd ..."
			local smartcd_repo_url=git://github.com/garethstockwell/smartcd.git
			git clone $smartcd_repo_url $(nativepath $smartcd_dir)
		fi

		echo "Installing smartcd ..."
		cd $smartcd_dir
		\\make install
		source ~/.smartcd/lib/core/smartcd
		smartcd config
		smartcd_install_templates
	}

	return 1
fi


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

function _metasystem_smartcd_install()
{
	local script_dir=~/.smartcd/scripts/$(pwd -P)
	local force=
	[[ "$1" == "-force" ]] && force=1
	[[ "$1" == "--force" ]] && force=1
	if [[ -e $script_dir/bash_enter && -z $force ]]; then
		echo "$script_dir/bash_enter already exists"
		echo "Use --force to overwrite it"
	else
		smartcd template install metasystem
	fi
}

function _metasystem_dirinfo_init()
{
	_metasystem_dirinfo_install $*
	_metasystem_smartcd_install $*
}

function metasystem_parse_dirinfo()
{
	local dir=$1
	local file=$dir/.metasystem-dirinfo
	if [[ -e $file ]]; then
		autostash METASYSTEM_DIRINFO_ROOT=$(dirname $file)
		metasystem-dirinfo.py -f $file
		. ${file}.sh
	fi
}

# Defer processing of bash_enter for $HOME until end of bashrc
SMARTCD_NOINITIAL=1

smartcd_config=~/.smartcd_config
if [[ -e $smartcd_config ]]; then
	source $smartcd_config
else
	echo "Error: $smartcd_config not found"
fi
unset smartcd_config

function _metasystem_cd()
{
	[[ "$1" != "-metasystem-init" ]] && smartcd cd $*
}

function _metasystem_export()
{
	autostash "$@"
}

function _metasystem_unset()
{
	empty_function
}

alias scd-ee='smartcd edit enter'
alias scd-el='smartcd edit leave'
alias scd-ti='smartcd template install'

#------------------------------------------------------------------------------
# Exported variables
#------------------------------------------------------------------------------

# Allow ~/.smartcd_config to be safely sourced by other scripts (e.g.
# bin/dirinfo-check.sh)
export SMARTCD_NOINITIAL

#SMARTCD_QUIET=1
VARSTASH_QUIET=1

export METASYSTEM_DIRINFO_SHELL_DEPRECATE=yes
#export METASYSTEM_DIRINFO_SHELL_IGNORE=yes

#------------------------------------------------------------------------------
# Exported functions
#------------------------------------------------------------------------------

