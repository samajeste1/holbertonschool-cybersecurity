#!/bin/bash
# Disable IP forwarding for IPv4 and IPv6

echo "=== Disabling IP Forwarding ==="
echo ""

echo "Current state:"
echo "  net.ipv4.ip_forward = $(sysctl -n net.ipv4.ip_forward)"
echo "  net.ipv6.conf.all.forwarding = $(sysctl -n net.ipv6.conf.all.forwarding)"
echo ""

echo "Applying changes..."
sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null 2>&1
echo "  net.ipv4.ip_forward = 0"
echo "  net.ipv6.conf.all.forwarding = 0"
echo ""

echo "Making persistent in /etc/sysctl.d/99-hardening.conf..."
CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"
grep -q 'net.ipv4.ip_forward' "$CONF" 2>/dev/null && \
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 0/' "$CONF" || \
    echo "net.ipv4.ip_forward = 0" >> "$CONF"
grep -q 'net.ipv6.conf.all.forwarding' "$CONF" 2>/dev/null && \
    sed -i 's/^net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding = 0/' "$CONF" || \
    echo "net.ipv6.conf.all.forwarding = 0" >> "$CONF"
echo ""

echo "Verification:"
IPV4=$(sysctl -n net.ipv4.ip_forward)
IPV6=$(sysctl -n net.ipv6.conf.all.forwarding)
if [ "$IPV4" = "0" ]; then
    echo "  IPv4 forwarding: DISABLED"
else
    echo "  IPv4 forwarding: STILL ENABLED (check permissions)"
fi
if [ "$IPV6" = "0" ]; then
    echo "  IPv6 forwarding: DISABLED"
else
    echo "  IPv6 forwarding: STILL ENABLED (check permissions)"
fi
