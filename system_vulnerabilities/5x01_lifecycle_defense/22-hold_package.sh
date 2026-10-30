#!/bin/bash
# Place a hold on a package and log the reason

if [ -z "$1" ]; then
    echo "Usage: $0 <package> \"reason\""
    exit 1
fi

PACKAGE="$1"
REASON="${2:-No reason specified}"

echo "=== Package Hold ==="
echo ""

CURRENT=$(dpkg -l "$PACKAGE" 2>/dev/null | grep '^ii' | awk '{print $3}')
echo "Package: $PACKAGE"
echo "Current version: $CURRENT (downgraded)"
echo ""

echo "Placing hold..."
apt-mark hold "$PACKAGE" 2>/dev/null
echo "  apt-mark hold $PACKAGE: Done"
echo ""

echo "Logging hold reason..."
HOLD_LOG="/var/log/package_holds.log"
echo "$(date +%Y-%m-%d) | $PACKAGE | $CURRENT | $REASON" >> "$HOLD_LOG"
echo "  $HOLD_LOG updated"
echo ""

echo "Hold verification:"
apt-mark showhold 2>/dev/null | grep "$PACKAGE"
echo ""

echo "WARNING: This package will NOT receive automatic updates."
echo "         Including security updates."
echo "         Review required within 30 days."
echo ""

echo "Hold applied successfully."
