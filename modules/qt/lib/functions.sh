# Various functions used by qt-*.sh scripts

#------------------------------------------------------------------------------
# Imports
#------------------------------------------------------------------------------

autoload metasystem_unixpath


#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function check_qt_build_dir()
{
	if [ -z "$QT_BUILD_DIR" ]
    then
        echo "Error: \$QT_BUILD_DIR is not set"
        exit 1
    fi

    if [ ! -d "$QT_BUILD_DIR" ]
    then
		echo "Error: \$QT_BUILD_DIR '$QT_BUILD_DIR' does not exist or is not a directory"
        exit 1
    fi
}

function check_qt_source_dir()
{
	if [ -z "$QT_SOURCE_DIR" ]
    then
        echo "Error: \$QT_SOURCE_DIR is not set"
        exit 1
    fi

    if [ ! -d "$QT_SOURCE_DIR" ]
    then
		echo "Error: \$QT_SOURCE_DIR '$QT_SOURCE_DIR' does not exist or is not a directory"
        exit 1
    fi
}

function check_pwd_in_qt_build_dir()
{
	check_qt_build_dir
	if [ -z `pwd | grep $(metasystem_unixpath $QT_BUILD_DIR)` ]
    then
		echo "Error: current path '$PWD' is not under \$QT_BUILD_DIR '$QT_BUILD_DIR'"
		exit 1
    fi
}

function check_pwd_in_qt_source_dir()
{
	check_qt_source_dir
	if [ -z `pwd | grep $(metasystem_unixpath $QT_SOURCE_DIR)` ]
    then
		echo "Error: current path '$PWD' is not under \$QT_SOURCE_DIR '$QT_SOURCE_DIR'"
		exit 1
    fi
}

function check_qtmobility_build_dir()
{
	if [ -z "$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR" ]
    then
        echo "Error: \$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR is not set"
        exit 1
    fi

    if [ ! -d "$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR" ]
    then
		echo "Error: \$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR '$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR' does not exist or is not a directory"
        exit 1
    fi
}

function check_qtmobility_source_dir()
{
	if [ -z "$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR" ]
    then
        echo "Error: \$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR is not set"
        exit 1
    fi

    if [ ! -d "$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR" ]
    then
		echo "Error: \$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR '$METASYSTEM_PROJECT_QTMOBILITY_SOURCE_DIR' does not exist or is not a directory"
        exit 1
    fi
}

function check_pwd_in_qtmobility_build_dir()
{
	check_qtmobility_build_dir
	if [ -z `pwd | grep $(metasystem_unixpath $METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR)` ]
    then
		echo "Error: current path '$PWD' is not under \$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR '$METASYSTEM_PROJECT_QTMOBILITY_BUILD_DIR'"
		exit 1
    fi
}

