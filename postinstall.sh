#!/bin/bash

# Shell script which is executed by bash *AFTER* complete installation is done
# (but *BEFORE* postupdate). Use with caution and remember, that all systems may
# be different!
#
# Exit code must be 0 if executed successfull. 
# Exit code 1 gives a warning but continues installation.
# Exit code 2 cancels installation.
#
# Will be executed as user "loxberry".
#
# You can use all vars from /etc/environment in this script.
#
# We add 5 additional arguments when executing this script:
# command <TEMPFOLDER> <NAME> <FOLDER> <VERSION> <BASEFOLDER>
#
# For logging, print to STDOUT. You can use the following tags for showing
# different colorized information during plugin installation:
#
# <OK> This was ok!"
# <INFO> This is just for your information."
# <WARNING> This is a warning!"
# <ERROR> This is an error!"
# <FAIL> This is a fail!"

# To use important variables from command line use the following code:
COMMAND=$0    # Zero argument is shell command
PTEMPDIR=$1   # First argument is temp folder during install
PSHNAME=$2    # Second argument is Plugin-Name for scipts etc.
PDIR=$3       # Third argument is Plugin installation folder
PVERSION=$4   # Forth argument is Plugin version
#LBHOMEDIR=$5 # Comes from /etc/environment now. Fifth argument is
              # Base folder of LoxBerry
PTEMPPATH=$6  # Sixth argument is full temp path during install (see also $1)

# Combine them with /etc/environment
PCGI=$LBPCGI/$PDIR
PHTML=$LBPHTML/$PDIR
PTEMPL=$LBPTEMPL/$PDIR
PDATA=$LBPDATA/$PDIR
PLOG=$LBPLOG/$PDIR # Note! This is stored on a Ramdisk now!
PCONFIG=$LBPCONFIG/$PDIR
PSBIN=$LBPSBIN/$PDIR
PBIN=$LBPBIN/$PDIR

# echo -n "<INFO> Current working folder is: "
# pwd
# echo "<INFO> Command is: $COMMAND"
# echo "<INFO> Temporary folder is: $PTEMPDIR"
# echo "<INFO> Temporary full path is: $PTEMPPATH"
# echo "<INFO> (Short) Name is: $PSHNAME"
# echo "<INFO> Installation folder is: $PDIR"
# echo "<INFO> Plugin version is: $PVERSION"
# echo "<INFO> Plugin CGI folder is: $PCGI"
# echo "<INFO> Plugin HTML folder is: $PHTML"
# echo "<INFO> Plugin Template folder is: $PTEMPL"
# echo "<INFO> Plugin Data folder is: $PDATA"
# echo "<INFO> Plugin Log folder (on RAMDISK!) is: $PLOG"
# echo "<INFO> Plugin CONFIG folder is: $PCONFIG"


echo "<INFO> Copy back existing config files"
cp -f -r /tmp/$PTEMPDIR\_upgrade/config/$PDIR/* $LBHOMEDIR/config/plugins/$PDIR/ 
echo "<INFO> Copy back existing data files"
cp -f -r /tmp/$PTEMPDIR\_upgrade/data/$PDIR/transform/custom/* $LBHOMEDIR/data/plugins/$PDIR/transform/custom/
chmod -R 0774 $LBHOMEDIR/data/plugins/$PDIR/transform/custom/

# echo "<INFO> Remove temporary folders"
# rm -f -r /tmp/$PTEMPDIR\_upgrade

echo "<INFO> Linking Mosquitto log to log folder"
ln -f -s /var/log/mosquitto/mosquitto.log $PLOG/

echo "<INFO> Creating data folders"
mkdir -p "$PDATA/transform/custom/udpin" > /dev/null
mkdir -p "$PDATA/transform/custom/mqttin" > /dev/null
mkdir -p "$PDATA/transform/shipped/mqttin" > /dev/null
mkdir -p "$PDATA/transform/shipped/udpin" > /dev/null

echo "<INFO> Updating configuration"
sudo $PBIN/updateconfig.pl

echo "<INFO> Starting MQTT Gateway service"
cd $PBIN
$PBIN/mqttgateway.pl > /dev/null 2>&1 &

# Exit with Status 0
exit 0
