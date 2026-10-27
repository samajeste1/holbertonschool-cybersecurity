#!/bin/bash
# Disable unnecessary services on a web server

echo "=== Service Minimization ==="
echo ""

echo "Checking for unnecessary services..."
echo ""

DISABLED=0

echo "Unnecessary services found:"
for svc in cups cups-browsed avahi-daemon bluetooth snapd postfix rpcbind nfs-server \
           ModemManager accounts-daemon whoopsie kerneloops apport; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q 'enabled'; then
        case "$svc" in
            cups|cups-browsed) DESC="Printing" ;;
            avahi-daemon) DESC="mDNS/DNS-SD" ;;
            bluetooth) DESC="Bluetooth" ;;
            snapd) DESC="Snap packages" ;;
            postfix) DESC="Mail server" ;;
            rpcbind) DESC="RPC portmapper" ;;
            nfs-server) DESC="NFS file sharing" ;;
            ModemManager) DESC="Modem management" ;;
            accounts-daemon) DESC="User accounts" ;;
            whoopsie) DESC="Error reporting" ;;
            kerneloops) DESC="Kernel error reporting" ;;
            apport) DESC="Crash reporting" ;;
            *) DESC="Unnecessary service" ;;
        esac
        echo "  $svc.service ($DESC) - Not needed on web server"
    fi
done
echo ""

echo "Disabling services..."
for svc in cups cups-browsed avahi-daemon bluetooth snapd postfix rpcbind nfs-server \
           ModemManager accounts-daemon whoopsie kerneloops apport; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q 'enabled'; then
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
        echo "  $svc.service: Disabled and stopped"
        DISABLED=$((DISABLED + 1))
    fi
done
echo ""

echo "Essential services preserved:"
for svc in sshd ssh apache2 nginx; do
    if systemctl is-active "$svc" 2>/dev/null | grep -q 'active'; then
        echo "  $svc.service: Running ✓"
    fi
done
echo ""

echo "Services reduced. Attack surface minimized."
