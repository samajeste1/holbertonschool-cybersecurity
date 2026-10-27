#!/bin/bash
# Restrict network tools to root-only access

echo "=== Network Tools Restriction ==="
echo ""

echo "Restricting access (root only)..."

for tool in nc ncat netcat nmap tcpdump wireshark tshark socat curl wget; do
    BIN=$(which "$tool" 2>/dev/null)
    if [ -n "$BIN" ] && [ -f "$BIN" ]; then
        OLD_PERMS=$(stat -c '%a' "$BIN")
        chmod 0750 "$BIN"
        chown root:root "$BIN"
        NEW_PERMS=$(stat -c '%a' "$BIN")
        echo "  $BIN: $NEW_PERMS (was $OLD_PERMS)"
    fi
done
echo ""

echo "Verification:"
for tool in nc nmap tcpdump; do
    BIN=$(which "$tool" 2>/dev/null)
    if [ -n "$BIN" ]; then
        PERMS=$(ls -la "$BIN" | awk '{print $1, $3, $4}')
        echo "  $tool: $PERMS"
    fi
done
echo ""

echo "Network tools restricted to root."
echo "Regular users can no longer execute these binaries."
