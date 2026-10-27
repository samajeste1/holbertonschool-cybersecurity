#!/bin/bash
# Enable strict reverse path filtering

echo "=== Enabling Reverse Path Filtering ==="
echo ""

CONF="/etc/sysctl.d/99-hardening.conf"
touch "$CONF"

echo "Setting strict mode (1) for all interfaces..."
sysctl -w net.ipv4.conf.all.rp_filter=1 >/dev/null 2>&1
sysctl -w net.ipv4.conf.default.rp_filter=1 >/dev/null 2>&1
echo "  net.ipv4.conf.all.rp_filter = 1"
echo "  net.ipv4.conf.default.rp_filter = 1"
echo ""

# Persist
for param in \
    "net.ipv4.conf.all.rp_filter = 1" \
    "net.ipv4.conf.default.rp_filter = 1"; do
    KEY=$(echo "$param" | cut -d= -f1 | xargs)
    grep -q "^$KEY" "$CONF" 2>/dev/null && \
        sed -i "s|^$KEY.*|$param|" "$CONF" || \
        echo "$param" >> "$CONF"
done

echo "Configuration saved to $CONF"
echo ""
echo "Reverse path filtering: STRICT MODE"
echo "Spoofed packets will be dropped."
