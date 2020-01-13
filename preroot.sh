#!/bin/bash
if [ -e /etc/mosquitto/conf.d/mqttgateway.conf ] ; then
	echo "<INFO> Removing Mosquitto config symlink from plugin before update"
	unlink /etc/mosquitto/conf.d/mqttgateway.conf
	echo "<INFO> The config symlink will be recreated during installation"
fi
