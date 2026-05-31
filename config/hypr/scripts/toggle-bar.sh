#!/bin/bash
if pgrep -x qs > /dev/null; then
    pkill -x qs
    waybar &
else
    pkill waybar 2>/dev/null
    QML_XHR_ALLOW_FILE_READ=1 qs --daemonize
fi
