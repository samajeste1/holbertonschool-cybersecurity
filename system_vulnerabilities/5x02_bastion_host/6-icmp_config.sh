#!/bin/bash
# Configure ICMP echo handling

echo "=== ICMP Configuration ==="
echo ""

CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"

echo "Disabling broadcast ping response (Smurf prevention)..."
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 >/dev/null 2>&1
echo "  net.ipv4.icmp_echo_ignore_broadcasts = 1"
echo ""

echo "Keeping unicast ping enabled for diagnostics."
sysctl -w net.ipv4.icmp_echo_ignore_all=0 >/dev/null 2>&1
echo "  net.ipv4.icmp_echo_ignore_all = 0"
echo ""

echo "Ignoring bogus ICMP error responses..."
sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 >/dev/null 2>&1
echo "  net.ipv4.icmp_ignore_bogus_error_responses = 1"
echo ""

# Persist
for param in \
    "net.ipv4.icmp_echo_ignore_broadcasts = 1" \
    "net.ipv4.icmp_echo_ignore_all = 0" \
    "net.ipv4.icmp_ignore_bogus_error_responses = 1"; do
    KEY=$(echo "$param" | cut -d= -f1 | xargs)
    grep -q "^$KEY" "$CONF" 2>/dev/null && \
        sed -i "s|^$KEY.*|$param|" "$CONF" || \
        echo "$param" >> "$CONF"
done

echo "Configuration saved to $CONF"
echo ""
echo "Broadcast ping: DISABLED"
echo "Unicast ping: ENABLED"
