#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
result=$(playerctl metadata --format '  {{artist}} — {{title}}' 2>/dev/null)
echo "${result:-}"
