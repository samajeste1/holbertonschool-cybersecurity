#!/bin/bash
# Safely remove stale lock files to enable package operations

echo "=== DPKG Unlock Procedure ==="
echo ""

echo "Checking for active package operations..."
APT_PROCS=$(pgrep -a apt 2>/dev/null || true)
DPKG_PROCS=$(pgrep -a dpkg 2>/dev/null || true)

if [ -n "$APT_PROCS" ]; then
    echo "  apt processes: RUNNING"
    echo "$APT_PROCS" | while read -r line; do
        echo "    $line"
    done
    echo ""
    echo "WARNING: Active apt process detected. Cannot safely remove locks."
    echo "Wait for the process to finish or kill it manually if stuck."
    exit 1
else
    echo "  apt processes: None"
fi

if [ -n "$DPKG_PROCS" ]; then
    echo "  dpkg processes: RUNNING"
    echo "$DPKG_PROCS" | while read -r line; do
        echo "    $line"
    done
    echo ""
    echo "WARNING: Active dpkg process detected. Cannot safely remove locks."
    exit 1
else
    echo "  dpkg processes: None"
fi
echo ""

echo "Removing stale lock files..."
for lockfile in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock; do
    if [ -f "$lockfile" ]; then
        rm -f "$lockfile"
        echo "  $lockfile: Removed"
    else
        echo "  $lockfile: Not present"
    fi
done
echo ""

echo "Verification:"
if [ ! -f /var/lib/dpkg/lock-frontend ] && [ ! -f /var/lib/dpkg/lock ]; then
    echo "  Package operations: UNLOCKED"
else
    echo "  Package operations: STILL LOCKED"
    exit 1
fi
echo ""

echo "DPKG unlocked successfully."
