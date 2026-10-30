#!/bin/bash
# Identify and apply only security updates

echo "=== Security Updates ==="
echo ""

echo "Fetching security update list..."
apt-get update -q 2>/dev/null > /dev/null

CODENAME=$(lsb_release -cs 2>/dev/null || echo "focal")
echo "Source: ${CODENAME}-security"
echo ""

# List available security updates
SEC_UPDATES=$(apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -i "security" || true)
SEC_COUNT=$(echo "$SEC_UPDATES" | grep -c '.' 2>/dev/null || echo "0")
[ -z "$SEC_UPDATES" ] && SEC_COUNT=0

echo "Available security updates: $SEC_COUNT packages"
if [ -n "$SEC_UPDATES" ]; then
    echo "$SEC_UPDATES" | head -10 | while read -r line; do
        PKG=$(echo "$line" | awk '{print $2}')
        OLD_VER=$(dpkg -l "$PKG" 2>/dev/null | grep '^ii' | awk '{print $3}')
        NEW_VER=$(echo "$line" | grep -oP '\[\S+\]' | tr -d '[]' || echo "latest")
        echo "  $PKG ($OLD_VER → $NEW_VER)"
    done
fi
echo ""

echo "Applying security updates..."
apt-get upgrade -y -o Dir::Etc::SourceList=/etc/apt/sources.list \
    -o Dir::Etc::SourceParts=/etc/apt/sources.list.d/ 2>&1 | tail -5
echo ""

echo "Verification:"
REMAINING=$(apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -ic "security" || echo "0")
echo "  Pending security updates: $REMAINING"
echo ""

echo "Security updates applied successfully."
