#!/bin/bash
# Will be executed as user "root".

# Enable auto-start of Mosquitto service
systemctl enable mosquitto.service
systemctl start mosquitto.service
exit 0
