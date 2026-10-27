#!/bin/bash
# Complete inventory of SUID and SGID binaries

echo "=== SUID/SGID Binary Audit ==="
echo ""

mkdir -p /var/log/hardening

SUID_COUNT=0
SGID_COUNT=0
UNKNOWN_COUNT=0

# Known safe SUID binaries
KNOWN_SAFE="sudo passwd su ping ssh-keysign"

echo "SUID binaries (run as owner):"
find / -perm -4000 -type f 2>/dev/null | sort | while read -r bin; do
    OWNER=$(stat -c '%U' "$bin" 2>/dev/null)
    NAME=$(basename "$bin")
    SUID_COUNT=$((SUID_COUNT + 1))

    STATUS="REVIEW NEEDED"
    for safe in $KNOWN_SAFE; do
        if [ "$NAME" = "$safe" ]; then
            STATUS="KNOWN SAFE"
            break
        fi
    done

    # Flag custom/non-standard paths
    if echo "$bin" | grep -q '/usr/local/'; then
        STATUS="UNKNOWN - HIGH RISK"
        UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
    fi

    printf "  %-40s %-8s %s\n" "$bin" "$OWNER" "$STATUS"
done
echo ""

echo "SGID binaries (run as group):"
find / -perm -2000 -type f 2>/dev/null | sort | while read -r bin; do
    GROUP=$(stat -c '%G' "$bin" 2>/dev/null)
    NAME=$(basename "$bin")
    SGID_COUNT=$((SGID_COUNT + 1))

    STATUS="REVIEW NEEDED"
    case "$NAME" in
        ssh-agent|crontab|wall|write|expiry|chage) STATUS="KNOWN SAFE" ;;
    esac

    printf "  %-40s %-8s %s\n" "$bin" "$GROUP" "$STATUS"
done
echo ""

TOTAL_SUID=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
TOTAL_SGID=$(find / -perm -2000 -type f 2>/dev/null | wc -l)
TOTAL_UNKNOWN=$(find /usr/local -perm -4000 -type f 2>/dev/null | wc -l)

echo "Summary:"
echo "  Total SUID: $TOTAL_SUID"
echo "  Total SGID: $TOTAL_SGID"
echo "  Unknown/Custom: $TOTAL_UNKNOWN (requires investigation)"
echo ""

REPORT="/var/log/hardening/suid_audit.txt"
{
    echo "SUID/SGID Audit Report - $(date)"
    echo "========================"
    echo ""
    echo "SUID Binaries:"
    find / -perm -4000 -type f -exec ls -la {} \; 2>/dev/null
    echo ""
    echo "SGID Binaries:"
    find / -perm -2000 -type f -exec ls -la {} \; 2>/dev/null
} > "$REPORT"

echo "Full report saved to: $REPORT"
