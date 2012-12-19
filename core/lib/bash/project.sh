# lib/bash/project.sh

function metasystem_project_env_prefix()
{
	local project=$1
	echo METASYSTEM_PROJECT_$(uppercase ${project//-/_})
}

