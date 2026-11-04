#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y squid
systemctl enable squid
if [ -f /etc/squid/squid.conf ] && [ ! -f /etc/squid/squid.conf.bak ]; then
    cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
fi
