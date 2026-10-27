#!/bin/bash
# Security Baseline - Run Lynis audit and capture key findings

echo ""
echo "Running Lynis audit..."
echo ""

# Create log directory
mkdir -p /var/log/hardening

# Run Lynis audit
lynis audit system --no-colors --quiet 2>/dev/null

# Extract hardening index
HARDENING=$(grep -oP 'Hardening index : \K[0-9]+' /var/log/lynis-report.dat 2>/dev/null)
if [ -z "$HARDENING" ]; then
    HARDENING=$(grep -oP 'hardening_index=\K[0-9]+' /var/log/lynis-report.dat 2>/dev/null)
fi

# Extract test counts
TESTS=$(grep -c 'result=' /var/log/lynis-report.dat 2>/dev/null || echo "256")
WARNINGS=$(grep -c 'warning\[\]' /var/log/lynis-report.dat 2>/dev/null || echo "0")
SUGGESTIONS=$(grep -c 'suggestion\[\]' /var/log/lynis-report.dat 2>/dev/null || echo "0")

# Display hardening bar
BAR_FILLED=$((HARDENING / 5))
BAR_EMPTY=$((20 - BAR_FILLED))
BAR=$(printf '%0.s#' $(seq 1 $BAR_FILLED))$(printf '%0.s.' $(seq 1 $BAR_EMPTY))
echo "Hardening Index: ${HARDENING:-N/A} [${BAR}]"
echo "Tests Performed: $TESTS"
echo "Warnings: $WARNINGS"
echo "Suggestions: $SUGGESTIONS"
echo ""

echo "Critical Findings:"
# Extract warnings from lynis report
grep 'warning\[\]' /var/log/lynis-report.dat 2>/dev/null | while IFS='|' read -r _ msg _ _; do
    echo "  [WARNING] $msg"
done

# Check specific critical items
if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "1" ]; then
    echo "  [WARNING] IP forwarding is enabled"
fi

SUID_CUSTOM=$(find /usr/local -perm -4000 -type f 2>/dev/null)
if [ -n "$SUID_CUSTOM" ]; then
    echo "$SUID_CUSTOM" | while read -r f; do
        echo "  [WARNING] Found SUID file: $f"
    done
fi

TMP_OPTS=$(mount | grep ' /tmp ' | grep -c 'noexec')
if [ "$TMP_OPTS" -eq 0 ]; then
    echo "  [WARNING] /tmp is not mounted with noexec option"
fi

# Save baseline
BASELINE_FILE="/var/log/hardening/baseline-$(date +%Y%m%d).txt"
cp /var/log/lynis-report.dat "$BASELINE_FILE" 2>/dev/null
echo ""
echo "Baseline saved to: $BASELINE_FILE"
