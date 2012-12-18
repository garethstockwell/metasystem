# zshrc.sh

# Find location of this script
export METASYSTEM_ROOT=$( builtin cd "$( dirname $0 )"/../.. && pwd )

source $(dirname $0)/shrc.sh

function test_export()
{
	echo test_export
}

export test_export

