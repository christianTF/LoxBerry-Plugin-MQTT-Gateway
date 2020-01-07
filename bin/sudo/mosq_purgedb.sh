#!/bin/bash
systemctl stop mosquitto
rm /var/lib/mosquitto/mosquitto.db
systemctl start mosquitto
