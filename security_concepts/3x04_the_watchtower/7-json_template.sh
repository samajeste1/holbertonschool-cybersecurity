#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

if grep -q 'json_fmt' /etc/rsyslog.conf; then
    exit 0
fi

cat >> /etc/rsyslog.conf << 'EOF'
$template json_fmt,"{\"time\":\"%timestamp%\", \"host\":\"%hostname%\", \"msg\":\"%msg%\"}"
EOF
