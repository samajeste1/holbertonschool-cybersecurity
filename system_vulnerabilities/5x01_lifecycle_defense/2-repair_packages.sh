#!/bin/bash
# Repair packages left in an inconsistent state

echo "=== Package Repair ==="
echo ""

echo "Configuring interrupted packages..."
dpkg --configure -a 2>&1 | while read -r line; do
    echo "  $line"
done
echo ""

echo "Fixing broken dependencies..."
apt-get install -f -y 2>&1 | tail -5 | while read -r line; do
    echo "  $line"
done
echo ""

echo "Verification:"
HALF_CONFIGURED=$(dpkg -l 2>/dev/null | grep -c '^.F' || echo "0")
echo "  Half-configured packages: $HALF_CONFIGURED"

BROKEN=$(apt-get check 2>&1 | grep -c 'Broken' || echo "0")
echo "  Broken dependencies: $BROKEN"
echo ""

if [ "$HALF_CONFIGURED" -eq 0 ] && [ "$BROKEN" -eq 0 ]; then
    echo "Package database: CONSISTENT"
else
    echo "Package database: STILL INCONSISTENT"
    echo "Manual intervention may be required."
fi
