#!/bin/bash

pgrep mosquitto
if [ $? -ne 0 ]; then
	echo "Restarting Mosquitto"
	systemctl restart mosquitto
else
	echo "Re-reading Mosquitto config"
	pkill -HUP mosquitto
fi
