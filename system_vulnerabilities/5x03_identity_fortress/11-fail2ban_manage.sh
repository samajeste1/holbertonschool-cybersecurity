#!/bin/bash
# Manage fail2ban: view status, view banned IPs, unban an IP

ACTION="${1:-status}"
PARAM="$2"

case "$ACTION" in
    status)
        echo "=== fail2ban Status ==="
        echo ""
        # Check service status
        if systemctl is-active fail2ban > /dev/null 2>&1; then
            echo "Service: Active"
        else
            echo "Service: Inactive"
        fi

        # List jails
        JAILS=$(fail2ban-client status 2>/dev/null | grep 'Jail list' | sed 's/.*:\s*//')
        echo "Jails: ${JAILS:-sshd}"
        echo ""

        # Show sshd jail stats
        echo "[sshd] Statistics:"
        STATS=$(fail2ban-client status sshd 2>/dev/null)
        CURRENTLY=$(echo "$STATS" | grep 'Currently banned' | awk '{print $NF}')
        TOTAL=$(echo "$STATS" | grep 'Total banned' | awk '{print $NF}')
        FAILED=$(echo "$STATS" | grep 'Currently failed' | awk '{print $NF}')
        echo "  Currently banned: ${CURRENTLY:-0}"
        echo "  Total banned: ${TOTAL:-0}"
        echo "  Currently failed: ${FAILED:-0}"
        ;;

    banned)
        echo "=== Banned IPs ==="
        echo ""
        echo "Jail: sshd"
        BANNED_LIST=$(fail2ban-client status sshd 2>/dev/null | grep 'Banned IP list' | sed 's/.*:\s*//')
        if [ -n "$BANNED_LIST" ]; then
            for ip in $BANNED_LIST; do
                echo "  $ip (banned)"
            done
        else
            echo "  No IPs currently banned"
        fi
        ;;

    unban)
        if [ -z "$PARAM" ]; then
            echo "Usage: $0 unban <IP_ADDRESS>"
            exit 1
        fi
        fail2ban-client set sshd unbanip "$PARAM" 2>/dev/null
        echo "IP $PARAM unbanned from jail sshd"
        ;;

    *)
        echo "Usage: $0 {status|banned|unban <IP>}"
        echo ""
        echo "Commands:"
        echo "  status     - Show fail2ban service and jail status"
        echo "  banned     - List all currently banned IPs"
        echo "  unban <IP> - Unban a specific IP address"
        exit 1
        ;;
esac
