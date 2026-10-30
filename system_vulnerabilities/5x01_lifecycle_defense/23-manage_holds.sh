#!/bin/bash
# Manage the hold registry: list all holds or release a hold

ACTION="${1:-list}"
HOLD_LOG="/var/log/package_holds.log"

case "$ACTION" in
    list)
        echo "=== Package Hold Registry ==="
        echo ""

        printf "%-16s %-12s %-13s %-5s %s\n" "Package" "Version" "Held Since" "Days" "Reason"

        TOTAL=0
        OLD_HOLDS=0
        TODAY_EPOCH=$(date +%s)

        # Read holds from log
        if [ -f "$HOLD_LOG" ]; then
            while IFS='|' read -r held_date pkg version reason; do
                held_date=$(echo "$held_date" | tr -d ' ')
                pkg=$(echo "$pkg" | tr -d ' ')
                version=$(echo "$version" | tr -d ' ')
                reason=$(echo "$reason" | sed 's/^ *//')

                # Check if package is still held
                if apt-mark showhold 2>/dev/null | grep -q "$pkg"; then
                    HELD_EPOCH=$(date -d "$held_date" +%s 2>/dev/null || echo "$TODAY_EPOCH")
                    DAYS=$(( (TODAY_EPOCH - HELD_EPOCH) / 86400 ))
                    printf "%-16s %-12s %-13s %-5s %s\n" "$pkg" "$version" "$held_date" "$DAYS" "$reason"
                    TOTAL=$((TOTAL + 1))
                    if [ "$DAYS" -gt 14 ]; then
                        OLD_HOLDS=$((OLD_HOLDS + 1))
                    fi
                fi
            done < "$HOLD_LOG"
        fi

        # Also show holds not in log
        apt-mark showhold 2>/dev/null | while read -r pkg; do
            if ! grep -q "$pkg" "$HOLD_LOG" 2>/dev/null; then
                printf "%-16s %-12s %-13s %-5s %s\n" "$pkg" "unknown" "unknown" "?" "Not logged"
                TOTAL=$((TOTAL + 1))
            fi
        done

        echo ""
        echo "Total holds: $TOTAL"
        echo "Holds older than 14 days: $OLD_HOLDS"
        ;;

    release)
        if [ -z "$2" ]; then
            echo "Usage: $0 release <package>"
            exit 1
        fi

        PACKAGE="$2"
        echo "Releasing hold on $PACKAGE..."
        apt-mark unhold "$PACKAGE" 2>/dev/null
        echo "  apt-mark unhold $PACKAGE: Done"

        # Remove from log
        if [ -f "$HOLD_LOG" ]; then
            sed -i "/$PACKAGE/d" "$HOLD_LOG"
            echo "  Removed from $HOLD_LOG"
        fi
        echo ""
        echo "Package will be upgraded on next automatic cycle."
        ;;

    *)
        echo "Usage: $0 {list|release <package>}"
        exit 1
        ;;
esac
