#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

touch /etc/rsyslog.d/50-default.conf
if ! grep -qxF '*.* @127.0.0.1:514' /etc/rsyslog.d/50-default.conf; then
    echo '*.* @127.0.0.1:514' >> /etc/rsyslog.d/50-default.conf
fi

systemctl restart rsyslog || service rsyslog restart
logger "Test Log Forwarding"
