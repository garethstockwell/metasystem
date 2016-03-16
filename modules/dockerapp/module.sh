# modules/dockerapp.sh

if [ -z $DOCKERAPP_SETUP_SCRIPT ]; then
    DOCKERAPP_SETUP_SCRIPT=$METASYSTEM_ROOT/../dockerapp/shell/shrc.sh
fi

if [ -e $DOCKERAPP_SETUP_SCRIPT ]; then
	source $DOCKERAPP_SETUP_SCRIPT
fi

