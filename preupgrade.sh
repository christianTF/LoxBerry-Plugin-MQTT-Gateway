#!/bin/bash

# To use important variables from command line use the following code:
ARGV0=$0 # Zero argument is shell command
# echo "<INFO> Command is: $ARGV0"

ARGV1=$1 # First argument is temp folder during install
# echo "<INFO> Temporary folder is: $ARGV1"

ARGV2=$2 # Second argument is Plugin-Name for scipts etc.
# echo "<INFO> (Short) Name is: $ARGV2"

ARGV3=$3 # Third argument is Plugin installation folder
# echo "<INFO> Installation folder is: $ARGV3"

ARGV4=$4 # Forth argument is Plugin version
# echo "<INFO> Installation folder is: $ARGV4"

ARGV5=$5 # Fifth argument is Base folder of LoxBerry
# echo "<INFO> Base folder is: $ARGV5"

ARGV6=$6 # Full path to temporary installation folder

echo "<INFO> Creating temporary folders for upgrading"
mkdir /tmp/$ARGV1\_upgrade
mkdir /tmp/$ARGV1\_upgrade/config
# mkdir /tmp/$ARGV1\_upgrade/log

echo "<INFO> Backing up existing config files"
cp -v -r $ARGV5/config/plugins/$ARGV3/ /tmp/$ARGV1\_upgrade/config

# echo "<INFO> Backing up existing log files"
# cp -v -r $ARGV5/log/plugins/$ARGV3/ /tmp/$ARGV1\_upgrade/log

# Exit with Status 0
exit 0
