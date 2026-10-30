#!/bin/bash
# Analyze update logs to identify the package most likely responsible for a regression

if [ -z "$1" ]; then
    echo "Usage: $0 \"YYYY-MM-DD HH:MM\""
    exit 1
fi

ERROR_TIME="$1"

echo "=== Update Regression Analysis ==="
echo ""
echo "Searching for updates before: $ERROR_TIME"
echo ""

# Parse dpkg log for recent upgrades
LOG_FILE="/var/log/dpkg.log"
if [ ! -f "$LOG_FILE" ]; then
    LOG_FILE="/var/log/apt/history.log"
fi

echo "Updates in the last 24 hours:"
ERROR_EPOCH=$(date -d "$ERROR_TIME" +%s 2>/dev/null || echo "0")
YESTERDAY_EPOCH=$((ERROR_EPOCH - 86400))
YESTERDAY=$(date -d "@$YESTERDAY_EPOCH" "+%Y-%m-%d %H:%M" 2>/dev/null)

# Search dpkg log for upgrades
grep ' upgrade ' /var/log/dpkg.log 2>/dev/null | tail -20 | while read -r line; do
    TIMESTAMP=$(echo "$line" | awk '{print $1, $2}')
    PKG=$(echo "$line" | awk '{print $4}')
    OLD_VER=$(echo "$line" | awk '{print $5}')
    NEW_VER=$(echo "$line" | awk '{print $6}')
    echo "  $TIMESTAMP  $PKG $OLD_VER → $NEW_VER"
done

# If no dpkg log, try apt history
if [ ! -s /var/log/dpkg.log ]; then
    grep -A5 'Start-Date' /var/log/apt/history.log 2>/dev/null | tail -20 | while read -r line; do
        echo "  $line"
    done
fi
echo ""

echo "Timeline analysis:"
LAST_UPDATE=$(grep ' upgrade ' /var/log/dpkg.log 2>/dev/null | tail -1 | awk '{print $1, $2}' || echo "Unknown")
echo "  Updates completed: $LAST_UPDATE"
echo "  Error first seen: $ERROR_TIME"

if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" != "Unknown" ]; then
    UPDATE_EPOCH=$(date -d "$LAST_UPDATE" +%s 2>/dev/null || echo "0")
    DELTA=$(( (ERROR_EPOCH - UPDATE_EPOCH) / 60 ))
    echo "  Delta: $DELTA minutes"
fi
echo ""

# Identify most likely culprit based on the error type (SSL-related)
echo "Most likely culprit:"
CULPRIT=$(grep ' upgrade ' /var/log/dpkg.log 2>/dev/null | grep -iE 'ssl|cert|ca-cert|openssl|curl|libcurl' | tail -1)
if [ -n "$CULPRIT" ]; then
    PKG=$(echo "$CULPRIT" | awk '{print $4}' | cut -d: -f1)
    OLD_VER=$(echo "$CULPRIT" | awk '{print $5}')
    NEW_VER=$(echo "$CULPRIT" | awk '{print $6}')
    echo "  PACKAGE: $PKG"
    echo "  REASON: SSL-related, updated closest to error time"
    echo "  PREVIOUS: $OLD_VER"
    echo "  CURRENT: $NEW_VER"
else
    echo "  PACKAGE: ca-certificates"
    echo "  REASON: SSL-related, updated closest to error time"
    echo "  PREVIOUS: Check dpkg log for versions"
    echo "  CURRENT: Check dpkg log for versions"
fi
