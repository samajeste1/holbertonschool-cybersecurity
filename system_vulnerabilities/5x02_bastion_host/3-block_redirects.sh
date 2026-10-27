#!/bin/bash
# Block ICMP redirect acceptance and sending

echo "=== Blocking ICMP Redirects ==="
echo ""

CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"

echo "Disabling redirect acceptance..."
sysctl -w net.ipv4.conf.all.accept_redirects=0 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.accept_redirects=0 >/dev/null 2>&1
sysctl -w net.ipv6.conf.all.accept_redirects=0 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.accept_redirects=0 >/dev/null 2>&1
echo "  net.ipv4.conf.all.accept_redirects = 0"
echo "  net.ipv4.conf.default.accept_redirects = 0"
echo "  net.ipv6.conf.all.accept_redirects = 0"
echo "  net.ipv6.conf.default.accept_redirects = 0"
echo ""

echo "Disabling redirect sending..."
sysctl -w net.ipv4.conf.all.send_redirects=0 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.send_redirects=0 >/dev/null 2>&1
echo "  net.ipv4.conf.all.send_redirects = 0"
echo "  net.ipv4.conf.default.send_redirects = 0"
echo ""

# Persist
for param in \
    "net.ipv4.conf.all.accept_redirects = 0" \
    "net.ipv4.conf.default.accept_redirects = 0" \
    "net.ipv6.conf.all.accept_redirects = 0" \
    "net.ipv6.conf.default.accept_redirects = 0" \
    "net.ipv4.conf.all.send_redirects = 0" \
    "net.ipv4.conf.default.send_redirects = 0"; do
    KEY=$(echo "$param" | cut -d= -f1 | xargs)
    grep -q "^$KEY" "$CONF" 2>/dev/null && \
        sed -i "s|^$KEY.*|$param|" "$CONF" || \
        echo "$param" >> "$CONF"
done

echo "Configuration saved to $CONF"
echo ""
echo "ICMP redirects: BLOCKED"
