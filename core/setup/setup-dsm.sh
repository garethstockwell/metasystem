#!/bin/ash

# Install required packages on Synology DSM

ipkg install bash
ipkg install less
ipkg install git
ipkg install python27
ipkg install sudo
ipkg install textutils

ln -s /opt/bin/python2 /opt/bin/python2.7
ln -s /opt/bin/python /opt/bin/python

