#!/bin/bash
ln -f -s /var/log/mosquitto/mosquitto.log REPLACELBPLOGDIR/
systemctl restart mosquitto
