#!/bin/bash

iptables -I INPUT -s "$1" -j DROP
iptables -I OUTPUT -d "$1" -j DROP
iptables -I FORWARD -s "$1" -j DROP
iptables -I FORWARD -d "$1" -j DROP

kill -STOP "$2"
