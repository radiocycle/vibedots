#!/bin/bash
# Перезапустить Waybar
pkill -x waybar 2>/dev/null
sleep 0.3
waybar &>/dev/null &
