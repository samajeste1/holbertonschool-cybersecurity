#!/bin/bash
# Block source-routed packets

echo "=== Blocking Source Routing ==="
echo ""

CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"

echo "Disabling source route acceptance..."
sysctl -w net.ipv4.conf.all.accept_source_route=0 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.accept_source_route=0 >/dev/null 2>&1
sysctl -w net.ipv6.conf.all.accept_source_route=0 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.accept_source_route=0 >/dev/null 2>&1
echo "  net.ipv4.conf.all.accept_source_route = 0"
echo "  net.ipv4.conf.default.accept_source_route = 0"
echo "  net.ipv6.conf.all.accept_source_route = 0"
echo "  net.ipv6.conf.default.accept_source_route = 0"
echo ""

# Persist
for param in \
    "net.ipv4.conf.all.accept_source_route = 0" \
    "net.ipv4.conf.default.accept_source_route = 0" \
    "net.ipv6.conf.all.accept_source_route = 0" \
    "net.ipv6.conf.default.accept_source_route = 0"; do
    KEY=$(echo "$param" | cut -d= -f1 | xargs)
    grep -q "^$KEY" "$CONF" 2>/dev/null && \
        sed -i "s|^$KEY.*|$param|" "$CONF" || \
        echo "$param" >> "$CONF"
done

echo "Configuration saved to $CONF"
echo ""
echo "Source-routed packets: BLOCKED"
