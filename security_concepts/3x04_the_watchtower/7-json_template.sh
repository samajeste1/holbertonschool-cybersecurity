#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

if grep -q 'json_fmt' /etc/rsyslog.conf; then
    exit 0
fi

fmt='{"time":"%timestamp%", "host":"%hostname%", "msg":"%msg%"}'
escaped=$(printf '%s' "$fmt" | sed 's/"/\\"/g')
printf '$template json_fmt,"%s"\n' "$escaped" >> /etc/rsyslog.conf
