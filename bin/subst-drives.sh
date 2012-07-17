#!/bin/sh

function dosubst() {
	label=$1
	drive=$2
	target=${3//\\/\/}

	substed=1

	echo -e "\n    $label ..."

	if [ -e $(unixpath $target) ]
	then
		if [ ! -e $(unixpath $drive) ]
		then
			echo "      Mapping $drive -> $target"
			subst $drive $target
#			test "$METASYSTEM_PLATFORM" == "mingw" && \
#				mount --replace $drive $(unixpath $drive)
		else
			# Check that the mapping is correct
			ucDrive=`echo $drive | sed -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`
			currentTarget=`subst | grep "^$ucDrive" | awk '{print \$3}'`
			currentTargetNative=
			test -n "$currentTarget" && currentTargetNative=$(unixpath $currentTarget)

			if [ "$currentTargetNative" == $(unixpath $target) ]
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

echo -e "\nMapping development drives"

LOCAL_BASELINE_DIR=d:\\baselines

if [ "$HOSTNAME" == "MW7NRIDIC4RTQV" ]
then
	HDD_DRIVE=d
else
	HDD_DRIVE=e
fi

LOCAL_ENVIRONMENT_DIR=$(nativepath ~/work/local/build)
HDD_ENVIRONMENT_DIR=${HDD_DRIVE}:\\qt\\environments

dosubst qt_mcl_hw110 n: ${LOCAL_ENVIRONMENT_DIR}\\qt\\mcl_201201_hw110_05

