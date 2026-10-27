#!/bin/bash
# Enable SYN cookies for SYN flood protection

echo "=== Enabling SYN Cookies ==="
echo ""

CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"

echo "Current state:"
echo "  net.ipv4.tcp_syncookies = $(sysctl -n net.ipv4.tcp_syncookies)"
echo ""

echo "Enabling SYN cookies..."
sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1
echo "  net.ipv4.tcp_syncookies = 1"
echo ""

# Persist
KEY="net.ipv4.tcp_syncookies"
grep -q "^$KEY" "$CONF" 2>/dev/null && \
    sed -i "s|^$KEY.*|$KEY = 1|" "$CONF" || \
    echo "$KEY = 1" >> "$CONF"

echo "Configuration saved to $CONF"
echo ""
echo "SYN flood protection: ENABLED"
