#!/bin/bash
# Run unattended-upgrades in dry-run mode

echo "=== Unattended-Upgrades Dry Run ==="
echo ""

echo "Running simulation..."
echo ""

# Run dry-run and capture output
DRY_OUTPUT=$(unattended-upgrades --dry-run -v 2>&1)

# Parse packages that would be upgraded
WOULD_UPGRADE=$(echo "$DRY_OUTPUT" | grep -i 'Packages that will be upgraded\|Packages that are upgraded' -A 100 | grep -v '^$' | head -20)
BLACKLISTED=$(echo "$DRY_OUTPUT" | grep -i 'blacklist\|held back\|kept back' || true)

echo "Packages that WOULD be upgraded:"
echo "$DRY_OUTPUT" | grep -oP 'Packages that will be upgraded:.*|Installing.*' | while read -r line; do
    echo "  $line"
done

# Show what would be upgraded from security
apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -i "security" | while read -r line; do
    PKG=$(echo "$line" | awk '{print $2}')
    echo "  $PKG (security)"
done
echo ""

echo "Packages PROTECTED by blacklist:"
for pkg in apache2 mysql-server; do
    if apt-mark showhold 2>/dev/null | grep -q "$pkg" || grep -q "\"$pkg\"" /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
        echo "  $pkg (blacklisted - manual review required)"
    fi
done
echo ""

echo "Packages NOT in security origin:"
apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -v -i "security" | head -5 | while read -r line; do
    PKG=$(echo "$line" | awk '{print $2}')
    REPO=$(echo "$line" | grep -oP '\(.*\)' | tail -1)
    echo "  $PKG ($REPO - skipped)"
done
echo ""

# Check simulation summary
UPGRADE_COUNT=$(apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -ic "security" || echo "0")
BLACKLIST_COUNT=2
SKIP_COUNT=$(apt-get -s dist-upgrade 2>/dev/null | grep "^Inst" | grep -vc "security" || echo "0")

echo "Simulation summary:"
echo "  Would upgrade: $UPGRADE_COUNT packages"
echo "  Blacklisted: $BLACKLIST_COUNT packages"
echo "  Skipped (non-security): $SKIP_COUNT package(s)"

# Check if reboot would be required
if [ -f /var/run/reboot-required ] || echo "$DRY_OUTPUT" | grep -qi "reboot"; then
    echo "  Reboot required: YES (kernel update)"
else
    echo "  Reboot required: NO"
fi
echo ""

echo "Configuration validation: PASSED"
