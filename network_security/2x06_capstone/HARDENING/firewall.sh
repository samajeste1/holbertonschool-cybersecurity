#!/bin/bash
#
# LogiCorp Gateway - Firewall Deployment Script
# IronShield Consulting
#
# Purpose: Deploy nftables firewall with default-deny policy,
#          VPN access rules, and NAT masquerading.
#
# Usage: Run as root on the target gateway
#   sudo bash firewall.sh
#
# WARNING: This script includes a panic button. If you get locked out,
#          the firewall resets automatically in 5 minutes.
#

set -euo pipefail

echo "=== LogiCorp Gateway - Firewall Deployment ==="

# --- Install nftables if needed ---
if ! command -v nft &>/dev/null; then
    echo "[+] Installing nftables..."
    apt-get update -qq && apt-get install -y -qq nftables
fi

# --- Panic Button: Schedule automatic reset in 5 minutes ---
echo "[!] PANIC BUTTON ACTIVATED - Firewall will auto-reset in 5 minutes"
echo "[!] If you get locked out, wait 5 minutes and reconnect."

nft flush ruleset
(sleep 300 && nft flush ruleset && echo "[PANIC] Firewall reset executed") &
PANIC_PID=$!
echo "[*] Panic timer PID: $PANIC_PID"

# --- Apply Firewall Rules ---
echo "[+] Applying firewall configuration..."

nft -f - <<'NFTABLES'
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Connection tracking - allow return traffic
        ct state established,related accept

        # Loopback - local process communication
        iifname "lo" accept

        # SSH - VPN interface only
        iifname "wg0" tcp dport 22 accept

        # FTP - VPN interface only (control + data + passive)
        iifname "wg0" tcp dport 21 accept
        iifname "wg0" tcp dport 20 accept
        iifname "wg0" tcp dport 40000-40100 accept

        # Wireguard - must be publicly accessible
        udp dport 51820 accept

        # ICMP - diagnostics and PMTU
        ip protocol icmp accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Return traffic for forwarded connections
        ct state established,related accept

        # VPN clients can route through gateway
        iifname "wg0" accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Source NAT for VPN client traffic leaving via WAN
        oifname "eth0" masquerade
    }
}
NFTABLES

echo "[+] Firewall rules applied successfully."
echo ""

# --- Enable IP Forwarding ---
echo "[+] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# --- Display Active Rules ---
echo ""
echo "=== Active Firewall Rules ==="
nft list ruleset
echo ""

# --- Verification ---
echo "=== Verification ==="
echo "[*] If you can see this message, SSH is still working."
echo "[*] Test VPN connectivity: ping 10.200.0.1"
echo "[*] Test from external: SSH should be BLOCKED from WAN"
echo ""
echo "[!] If everything works, cancel the panic timer:"
echo "    kill $PANIC_PID"
echo ""
echo "[!] To make rules persistent:"
echo "    nft list ruleset > /etc/nftables.conf"
echo "    systemctl enable nftables"

# --- Persist Rules ---
echo "[+] Saving rules for persistence..."
nft list ruleset > /etc/nftables.conf
systemctl enable nftables 2>/dev/null || true

echo ""
echo "=== Firewall Deployment Complete ==="
