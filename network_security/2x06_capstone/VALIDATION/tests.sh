#!/bin/bash
#
# LogiCorp Gateway - Automated Compliance Check
# IronShield Consulting
#
# Purpose: Verify security posture of the hardened gateway.
#          Runs automated checks and reports pass/fail status.
#
# Usage: Run as root on the target gateway
#   sudo bash tests.sh
#

PASS=0
FAIL=0
TOTAL=0

check() {
    local description="$1"
    local result="$2"
    TOTAL=$((TOTAL + 1))

    if [ "$result" -eq 0 ]; then
        echo "[PASS] $description"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $description"
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================"
echo " LogiCorp Gateway - Compliance Check"
echo " IronShield Consulting"
echo " Date: $(date)"
echo "========================================"
echo ""

# ==========================================
# FIREWALL CHECKS
# ==========================================
echo "--- Firewall Status ---"

# Check nftables is active
systemctl is-active --quiet nftables 2>/dev/null
check "nftables service is active" $?

# Check default INPUT policy is DROP
nft list chain inet filter input 2>/dev/null | grep -q "policy drop"
check "Firewall default INPUT policy is DROP" $?

# Check default FORWARD policy is DROP
nft list chain inet filter forward 2>/dev/null | grep -q "policy drop"
check "Firewall default FORWARD policy is DROP" $?

# Check default OUTPUT policy is ACCEPT
nft list chain inet filter output 2>/dev/null | grep -q "policy accept"
check "Firewall default OUTPUT policy is ACCEPT" $?

# Check connection tracking rule exists
nft list chain inet filter input 2>/dev/null | grep -q "ct state established,related accept"
check "Connection tracking rule exists in input chain" $?

# Check Wireguard port is allowed
nft list chain inet filter input 2>/dev/null | grep -q "udp dport 51820 accept"
check "UDP port 51820 (Wireguard) is allowed" $?

# Check SSH is restricted to VPN
nft list chain inet filter input 2>/dev/null | grep -q 'iifname "wg0" tcp dport 22 accept'
SSH_VPN_RESTRICTED=$?
# Also check it's NOT open on all interfaces
nft list ruleset 2>/dev/null | grep -q "tcp dport 22 accept" && ! nft list ruleset 2>/dev/null | grep "tcp dport 22 accept" | grep -qv "wg0"
check "SSH restricted to VPN interface only" $SSH_VPN_RESTRICTED

# Check NAT masquerade exists
nft list ruleset 2>/dev/null | grep -q "masquerade"
check "NAT masquerade rule exists" $?

# Check no unexpected ACCEPT rules on input (basic check)
ACCEPT_COUNT=$(nft list chain inet filter input 2>/dev/null | grep -c "accept" || echo "0")
if [ "$ACCEPT_COUNT" -le 10 ]; then
    check "No excessive ACCEPT rules in input chain (count: $ACCEPT_COUNT)" 0
else
    check "No excessive ACCEPT rules in input chain (count: $ACCEPT_COUNT)" 1
fi

echo ""

# ==========================================
# SSH SECURITY CHECKS
# ==========================================
echo "--- SSH Configuration ---"

# Check root login disabled
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config
check "SSH root login is disabled" $?

# Check password auth disabled
grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config
check "SSH password authentication is disabled" $?

# Check pubkey auth enabled
grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config
check "SSH public key authentication is enabled" $?

# Check SSH is running
systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null
check "SSH service is running" $?

echo ""

# ==========================================
# VPN CHECKS
# ==========================================
echo "--- VPN Status ---"

# Check Wireguard interface exists
ip link show wg0 &>/dev/null
check "VPN interface wg0 exists" $?

# Check Wireguard interface is UP
ip link show wg0 2>/dev/null | grep -q "UP"
check "VPN interface wg0 is UP" $?

# Check Wireguard has correct IP
ip addr show wg0 2>/dev/null | grep -q "10.200.0.1"
check "VPN interface has correct IP (10.200.0.1)" $?

# Check Wireguard is listening on correct port
wg show wg0 2>/dev/null | grep -q "listening port: 51820"
check "Wireguard listening on port 51820" $?

# Check Wireguard has peers configured
PEER_COUNT=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
if [ "$PEER_COUNT" -ge 1 ]; then
    check "Wireguard has peers configured (count: $PEER_COUNT)" 0
else
    check "Wireguard has peers configured (count: $PEER_COUNT)" 1
fi

# Check wg-quick enabled at boot
systemctl is-enabled --quiet wg-quick@wg0 2>/dev/null
check "Wireguard enabled at boot" $?

echo ""

# ==========================================
# NETWORK CONFIGURATION CHECKS
# ==========================================
echo "--- Network Configuration ---"

# Check IP forwarding
IPFWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
if [ "$IPFWD" = "1" ]; then
    check "IP forwarding is enabled" 0
else
    check "IP forwarding is enabled" 1
fi

# Check IP forwarding persistent
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null
check "IP forwarding is persistent in sysctl.conf" $?

echo ""

# ==========================================
# SERVICE CHECKS
# ==========================================
echo "--- Service Status ---"

# Check unnecessary services are stopped
for svc in apache2 nginx cups avahi-daemon bluetooth; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        check "Unnecessary service '$svc' is stopped" 1
    else
        check "Unnecessary service '$svc' is stopped" 0
    fi
done

echo ""

# ==========================================
# FILE PERMISSION CHECKS
# ==========================================
echo "--- File Permissions ---"

# Check SSH config permissions
SSHD_PERMS=$(stat -c %a /etc/ssh/sshd_config 2>/dev/null)
if [ "$SSHD_PERMS" = "600" ]; then
    check "SSH config has secure permissions (600)" 0
else
    check "SSH config has secure permissions (600), got: $SSHD_PERMS" 1
fi

# Check Wireguard config permissions
if [ -f /etc/wireguard/wg0.conf ]; then
    WG_PERMS=$(stat -c %a /etc/wireguard/wg0.conf 2>/dev/null)
    if [ "$WG_PERMS" = "600" ]; then
        check "Wireguard config has secure permissions (600)" 0
    else
        check "Wireguard config has secure permissions (600), got: $WG_PERMS" 1
    fi
else
    check "Wireguard config exists at /etc/wireguard/wg0.conf" 1
fi

# Check private key permissions
if [ -f /etc/wireguard/server_private ]; then
    KEY_PERMS=$(stat -c %a /etc/wireguard/server_private 2>/dev/null)
    if [ "$KEY_PERMS" = "600" ]; then
        check "Server private key has secure permissions (600)" 0
    else
        check "Server private key has secure permissions (600), got: $KEY_PERMS" 1
    fi
else
    check "Server private key exists" 1
fi

echo ""

# ==========================================
# RESULTS
# ==========================================
echo "========================================"
echo " RESULTS: ${PASS}/${TOTAL} checks passed"
if [ "$FAIL" -gt 0 ]; then
    echo " FAILURES: ${FAIL} checks failed"
    echo " STATUS: NON-COMPLIANT"
else
    echo " STATUS: COMPLIANT"
fi
echo "========================================"

exit $FAIL
