#!/bin/bash
# Will be executed as user "root".

# Enable auto-start of Mosquitto service
systemctl enable mosquitto
systemctl start mosquitto

exit 0
