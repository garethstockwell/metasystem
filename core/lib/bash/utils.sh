# lib/bash/utils.sh

[[ -n $METASYSTEM_DEBUG ]] && echo "[$$] lib/bash/utils.sh"

#------------------------------------------------------------------------------
# Executed on load
#------------------------------------------------------------------------------

[[ -z $METASYSTEM_CORE_LIB ]] && echo "Error: METASYSTEM_CORE_LIB not defined" >&2


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function metasystem_declare_stub()
{
	local lib=$1
	local func=$2
	[[ -n $METASYSTEM_DEBUG ]] && echo "[$$] metasystem_declare_stub $lib $func" >&2
	[[ -z $(declare -f $func) ]] &&\
		eval "$(echo "${func}() { metasystem_load_lib ${lib} && ${func} \"\$@\"; }")"
}

function metasystem_load_lib()
{
	local lib=$1
	[[ -n $METASYSTEM_DEBUG ]] && echo "[$$] load_lib $lib" >&2
	eval "source $METASYSTEM_CORE_LIB_BASH/$lib"
}


#------------------------------------------------------------------------------
# Stubs
#------------------------------------------------------------------------------

# build.sh
metasystem_declare_stub build.sh number_of_processors

# func.sh
metasystem_declare_stub func.sh func_exists
metasystem_declare_stub func.sh func_rename
metasystem_declare_stub func.sh func_prepend_to
metasystem_declare_stub func.sh func_append_to
metasystem_declare_stub func.sh func_source

# list.sh
metasystem_declare_stub list.sh list_append
metasystem_declare_stub list.sh list_remove
metasystem_declare_stub list.sh list_contains
metasystem_declare_stub list.sh list_pipe_separated

# map.sh
metasystem_declare_stub map.sh map_put
metasystem_declare_stub map.sh map_get
metasystem_declare_stub map.sh map_clear

# misc.sh
metasystem_declare_stub misc.sh assert_superuser
metasystem_declare_stub misc.sh assert_not_superuser
metasystem_declare_stub misc.sh assert_is_linux
metasystem_declare_stub misc.sh assert_is_ubuntu
metasystem_declare_stub misc.sh log_file
metasystem_declare_stub misc.sh command_exists

# path.sh
metasystem_declare_stub path.sh path_split
metasystem_declare_stub path.sh path_append
metasystem_declare_stub path.sh path_append_if_exists
metasystem_declare_stub path.sh path_prepend
metasystem_declare_stub path.sh path_prepend_if_exists
metasystem_declare_stub path.sh path_remove
metasystem_declare_stub path.sh path_shorten

# platform.sh
metasystem_declare_stub platform.sh query_platform

# string.sh
metasystem_declare_stub string.sh lowercase
metasystem_declare_stub string.sh uppercase

