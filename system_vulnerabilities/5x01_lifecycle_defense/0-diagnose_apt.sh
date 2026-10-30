#!/bin/bash
# Comprehensive diagnostic of APT/DPKG system state

echo "=== APT/DPKG Diagnostic ==="
echo ""

# Check lock files
echo "Lock files:"
for lockfile in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock; do
    if [ -f "$lockfile" ]; then
        # Check if any process actually holds the lock
        HOLDER=$(fuser "$lockfile" 2>/dev/null)
        if [ -n "$HOLDER" ]; then
            echo "  $lockfile: LOCKED (PID $HOLDER)"
        else
            echo "  $lockfile: PRESENT (stale)"
        fi
    else
        echo "  $lockfile: OK"
    fi
done
echo ""

# Check package states
echo "Package states:"
HALF_CONFIGURED=$(dpkg -l 2>/dev/null | grep -c '^iF\|^hF' || true)
HALF_CONFIGURED_LIST=$(dpkg --audit 2>/dev/null | grep 'half-configured' | awk '{print $1}' || true)
if [ -z "$HALF_CONFIGURED_LIST" ]; then
    HALF_CONFIGURED_LIST=$(dpkg -l 2>/dev/null | grep '^.F' | awk '{print $2}' || true)
fi
HALF_CONFIGURED_COUNT=$(echo "$HALF_CONFIGURED_LIST" | grep -c '.' 2>/dev/null || echo "0")
if [ "$HALF_CONFIGURED_COUNT" -eq 0 ] 2>/dev/null; then
    HALF_CONFIGURED_COUNT=$(dpkg -l 2>/dev/null | grep -c '^iF' || echo "0")
    HALF_CONFIGURED_LIST=$(dpkg -l 2>/dev/null | grep '^iF' | awk '{print $2}')
fi
echo "  Half-configured: $HALF_CONFIGURED_COUNT packages"
if [ -n "$HALF_CONFIGURED_LIST" ]; then
    echo "$HALF_CONFIGURED_LIST" | while read -r pkg; do
        [ -n "$pkg" ] && echo "    - $pkg"
    done
fi

HALF_INSTALLED=$(dpkg -l 2>/dev/null | grep -c '^iH' || echo "0")
echo "  Half-installed: $HALF_INSTALLED packages"

CONFIG_FILES=$(dpkg -l 2>/dev/null | grep -c '^rc' || echo "0")
echo "  Config-files: $CONFIG_FILES packages"
echo ""

# Check APT sources
echo "APT sources:"
VALID=0
INVALID=0
INVALID_FILES=""

# Check main sources.list
if [ -f /etc/apt/sources.list ]; then
    MAIN_COUNT=$(grep -c '^deb ' /etc/apt/sources.list 2>/dev/null || echo "0")
    VALID=$((VALID + MAIN_COUNT))
fi

# Check sources.list.d
for srcfile in /etc/apt/sources.list.d/*.list 2>/dev/null; do
    [ -f "$srcfile" ] || continue
    while IFS= read -r line; do
        # Skip comments and empty lines
        echo "$line" | grep -q '^#\|^$' && continue
        echo "$line" | grep -q '^deb ' || continue
        REPO_URL=$(echo "$line" | awk '{print $2}')
        # Test if the repository is reachable
        if apt-get update -o Dir::Etc::sourcelist="$srcfile" -o Dir::Etc::sourceparts="/dev/null" 2>&1 | grep -qi 'err\|fail\|invalid\|could not'; then
            INVALID=$((INVALID + 1))
            INVALID_FILES="$INVALID_FILES $srcfile"
        else
            VALID=$((VALID + 1))
        fi
    done < "$srcfile"
done 2>/dev/null

echo "  Valid: $VALID"
if [ "$INVALID" -gt 0 ]; then
    echo "  Invalid: $INVALID ($INVALID_FILES)"
else
    echo "  Invalid: 0"
fi
echo ""

# Check last APT operation
LAST_LOG=$(ls -t /var/log/apt/term.log* 2>/dev/null | head -1)
if [ -n "$LAST_LOG" ]; then
    if echo "$LAST_LOG" | grep -q '.gz$'; then
        LAST_OP=$(zcat "$LAST_LOG" 2>/dev/null | grep 'Log started\|Log ended' | tail -2)
    else
        LAST_OP=$(grep 'Log started\|Log ended' "$LAST_LOG" 2>/dev/null | tail -2)
    fi
    LAST_START=$(echo "$LAST_OP" | grep 'Log started' | tail -1 | sed 's/Log started: //')
    LAST_END=$(echo "$LAST_OP" | grep 'Log ended' | tail -1)
    if [ -n "$LAST_START" ]; then
        if [ -z "$LAST_END" ]; then
            echo "Last APT operation: $LAST_START (INTERRUPTED)"
        else
            echo "Last APT operation: $LAST_START (completed)"
        fi
    fi
else
    echo "Last APT operation: Unknown"
fi
echo ""

# Check DPKG database consistency
DPKG_STATUS=$(dpkg --audit 2>&1)
if [ -n "$DPKG_STATUS" ]; then
    echo "DPKG database: INCONSISTENT"
    echo "Action required: YES"
else
    echo "DPKG database: CONSISTENT"
    echo "Action required: NO"
fi
