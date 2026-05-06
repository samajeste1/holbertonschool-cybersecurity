#!/bin/bash
# Network hardening functions

harden_network() {
    log "[INFO] Starting network hardening"

    # N-01 / N-02: Create firewall policy file
    mkdir -p /etc/hardening
    cat > /etc/hardening/firewall.rules << EOF
DEFAULT_INPUT=deny
DEFAULT_OUTPUT=allow
ALLOW_TCP=${SSH_PORT}
ALLOW_TCP=80
ALLOW_TCP=443
EOF
    log "[INFO] Firewall policy created: ports ${SSH_PORT}, 80, 443 ALLOWED."

    # N-03: Kernel hardening - disable IP forwarding, ignore ICMP
    if ! grep -q "net.ipv4.ip_forward=0" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv4.icmp_echo_ignore_all=1" /etc/sysctl.conf; then
        echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
    fi
    sysctl -p /etc/sysctl.conf >> "$LOG_FILE" 2>&1
    log "[INFO] Kernel parameters hardened (IP forwarding disabled, ICMP ignored)."
}
