#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

cp -a /etc/rsyslog.conf /etc/rsyslog.conf.bak

sed -i \
    -e 's/^#[[:space:]]*module(load="imudp")/module(load="imudp")/' \
    -e 's/^#[[:space:]]*input(type="imudp" port="514")/input(type="imudp" port="514")/' \
    -e 's/^#[[:space:]]*module(load="imtcp")/module(load="imtcp")/' \
    -e 's/^#[[:space:]]*input(type="imtcp" port="514")/input(type="imtcp" port="514")/' \
    -e 's/^#[[:space:]]*\$ModLoad imudp/$ModLoad imudp/' \
    -e 's/^#[[:space:]]*\$UDPServerRun 514/$UDPServerRun 514/' \
    -e 's/^#[[:space:]]*\$ModLoad imtcp/$ModLoad imtcp/' \
    -e 's/^#[[:space:]]*\$InputTCPServerRun 514/$InputTCPServerRun 514/' \
    /etc/rsyslog.conf

systemctl restart rsyslog || service rsyslog restart
