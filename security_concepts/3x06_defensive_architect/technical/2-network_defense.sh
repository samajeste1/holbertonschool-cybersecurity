#!/bin/bash
# Network Defense Script - Nexus Financial
# UFW Default Deny + micro-segmentation
# Idempotent: safe to run multiple times

set -euo pipefail

LOG="/var/log/nexus_network.log"
echo "Starting network defense configuration" | tee -a "$LOG"

# Install UFW if missing
if ! command -v ufw > /dev/null 2>&1; then
    apt-get install -y -qq ufw
fi

# Reset UFW to clean state
ufw --force reset

# Default deny all
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
echo "Default policy: DENY ALL" | tee -a "$LOG"

# Loopback
ufw allow in on lo
ufw allow out on lo

# SSH - bastion host only (192.168.1.10)
ufw allow in from 192.168.1.10 to any port 22 proto tcp
echo "SSH allowed from bastion 192.168.1.10 only" | tee -a "$LOG"

# HTTPS and HTTP
ufw allow in to any port 443 proto tcp
ufw allow in to any port 80 proto tcp
ufw allow out to any port 443 proto tcp
ufw allow out to any port 80 proto tcp

# PostgreSQL 5432 - web server only (192.168.1.20)
# CRITICAL: was open to 0.0.0.0/0, now restricted to internal webserver
ufw allow in from 192.168.1.20 to any port 5432 proto tcp
echo "PostgreSQL 5432: allowed from 192.168.1.20 only" | tee -a "$LOG"

# WireGuard VPN for remote Bali team
ufw allow in to any port 51820 proto udp
ufw allow in from 10.8.0.0/24 to any port 443 proto tcp

# DNS and NTP outbound
ufw allow out to any port 53 proto udp
ufw allow out to any port 53 proto tcp
ufw allow out to any port 123 proto udp

# Centralized logging outbound
ufw allow out to 192.168.1.50 port 514 proto udp
ufw allow out to 192.168.1.50 port 514 proto tcp

# Enable UFW
ufw logging on
echo "y" | ufw enable
echo "UFW enabled with default deny" | tee -a "$LOG"

# Verify port 5432 is not open to internet
ufw status verbose | tee -a "$LOG"
echo "Network defense configuration complete" | tee -a "$LOG"
