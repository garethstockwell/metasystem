#!/bin/bash

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

source $METASYSTEM_CORE_LIB_BASH/path.sh


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function dosubst() {
	label=$1
	drive=$2
	target=${3//\\/\/}

	substed=1

	echo -e "\n    $label ..."

	if [ -e $(metasystem_unixpath $target) ]
	then
		if [ ! -e $(metasystem_unixpath $drive) ]
		then
			echo "      Mapping $drive -> $target"
			subst $drive $target
#			test "$METASYSTEM_PLATFORM" == "mingw" && \
#				mount --replace $drive $(metasystem_unixpath $drive)
		else
			# Check that the mapping is correct
			ucDrive=`echo $drive | sed -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`
			currentTarget=`subst | grep "^$ucDrive" | awk '{print \$3}'`
			currentTargetNative=
			test -n "$currentTarget" && currentTargetNative=$(metasystem_unixpath $currentTarget)

			if [ "$currentTargetNative" == $(metasystem_unixpath $target) ]
			then
				echo "      Already mapped $drive -> $currentTarget"
			else
				echo "      Warning: currently mapped $drive -> $currentTarget"
				echo "      but need to map $drive -> $target"
				substed=0
			fi
		fi
	else
		echo "      Error: target $target not found"
		substed=0
	fi
}


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

echo -e "\nMapping development drives"

LOCAL_BASELINE_DIR=d:\\baselines

if [ "$HOSTNAME" == "MW7NRIDIC4RTQV" ]
then
	HDD_DRIVE=d
else
	HDD_DRIVE=e
fi

LOCAL_ENVIRONMENT_DIR=$(metasystem_nativepath ~/work/local/build)
HDD_ENVIRONMENT_DIR=${HDD_DRIVE}:\\qt\\environments

dosubst qt_mcl_hw110 n: ${LOCAL_ENVIRONMENT_DIR}\\qt\\mcl_201201_hw110_05

