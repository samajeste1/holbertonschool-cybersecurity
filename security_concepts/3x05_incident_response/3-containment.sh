#!/bin/bash
# Containment Script - Nexus Financial Incident Response
# Blocks attacker IP via iptables and freezes malicious process for forensic analysis
# Usage: ./3-containment.sh <IP_ADDRESS> <PID>

IP="$1"
PID="$2"

iptables -I INPUT -s "$IP" -j DROP
iptables -I OUTPUT -d "$IP" -j DROP

kill -STOP "$PID"
