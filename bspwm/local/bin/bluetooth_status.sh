#!/bin/bash

# Function to check Bluetooth status
check_bluetooth_status() {
    bluetooth_status=$(bluetoothctl show | grep -i "Powered" | awk '{print $2}')
    
    if [ "$bluetooth_status" == "yes" ]; then
        # Bluetooth is on, check for connected devices
        #connected_devices=$(bluetoothctl devices | grep Device | wc -l)
        #if [ "$connected_devices" -gt 0 ]; then
        #    echo "Connected"
	connected_devices=$(bluetoothctl devices | grep -Eo '^Device [0-9A-F:]{17} (.+)$' | while read -r line; do
            uuid=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^[ \t]*//')
            connected=$(bluetoothctl info "$uuid" | awk '/Connected:/{print $2}')
            if [ "$connected" == "yes" ]; then
                echo "$name"
            fi
        done)
        if [ -n "$connected_devices" ]; then
            echo "$connected_devices"
        else
            echo "On"
        fi
    elif [ "$bluetooth_status" == "no" ]; then
        echo "Off"
    else
        echo "Unknown"
    fi
}

# Check Bluetooth status and echo the result
check_bluetooth_status
