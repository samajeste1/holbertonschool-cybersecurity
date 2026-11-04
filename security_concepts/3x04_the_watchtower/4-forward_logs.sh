#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

conf="/etc/rsyslog.d/50-default.conf"
rule="*.* @127.0.0.1:514"

touch "$conf"
if ! grep -qxF "$rule" "$conf"; then
    echo "$rule" >> "$conf"
fi

systemctl restart rsyslog || service rsyslog restart
logger "Test Log Forwarding"
