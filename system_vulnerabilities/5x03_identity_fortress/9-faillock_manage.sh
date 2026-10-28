#!/bin/bash
# Manage faillock status: view locked accounts, show user details, reset locks

ACTION="${1:-status}"

# Parse command using conditional logic
parse_command() {
    if [ "$1" == "status" ] || [ -z "$1" ]; then
        ACTION="status"
    elif [ "$1" == "show" ]; then
        ACTION="show"
    elif [ "$1" == "reset" ]; then
        ACTION="reset"
    fi
}
parse_command "$1"

case "$ACTION" in
    status)
        echo "=== Faillock Status ==="
        echo ""
        echo "Locked accounts:"
        # List all users with failed attempts
        FOUND=0
        for userdir in /var/run/faillock/*; do
            if [ -f "$userdir" ]; then
                username=$(basename "$userdir")
                FAILURES=$(faillock --user "$username" 2>/dev/null | grep -c 'V')
                if [ "$FAILURES" -ge 5 ] 2>/dev/null; then
                    LOCK_TIME=$(faillock --user "$username" 2>/dev/null | tail -1 | awk '{print $2, $3}')
                    echo "  $username: $FAILURES failures (locked at $LOCK_TIME)"
                    FOUND=1
                fi
            fi
        done
        if [ "$FOUND" -eq 0 ]; then
            faillock 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "  No locked accounts found"
            fi
        fi
        ;;

    show)
        if [ -z "$2" ]; then
            echo "Usage: $0 show <username>"
            exit 1
        fi
        echo "=== Faillock Details: $2 ==="
        echo ""
        echo "Recent failures:"
        faillock --user "$2" 2>/dev/null | grep -v '^$' | while read -r line; do
            if echo "$line" | grep -q 'V\|I'; then
                TIMESTAMP=$(echo "$line" | awk '{print $1, $2}')
                SOURCE=$(echo "$line" | awk '{print $NF}')
                echo "  $TIMESTAMP - Failed auth from $SOURCE"
            fi
        done

        # Check if locked
        FAIL_COUNT=$(faillock --user "$2" 2>/dev/null | grep -c 'V')
        if [ "$FAIL_COUNT" -ge 5 ] 2>/dev/null; then
            echo ""
            echo "Status: LOCKED"
            echo "Unlocks automatically after 15 minutes"
        else
            echo ""
            echo "Status: NOT LOCKED ($FAIL_COUNT failures)"
        fi
        ;;

    reset)
        if [ -z "$2" ]; then
            echo "Usage: $0 reset <username>"
            exit 1
        fi
        faillock --user "$2" --reset 2>/dev/null
        echo "Account $2: Lock cleared"
        ;;

    *)
        echo "Usage: $0 {status|show <user>|reset <user>}"
        echo ""
        echo "Commands:"
        echo "  status          - Show all locked accounts"
        echo "  show <user>     - Show failed attempts for a user"
        echo "  reset <user>    - Clear lock for a user"
        exit 1
        ;;
esac
