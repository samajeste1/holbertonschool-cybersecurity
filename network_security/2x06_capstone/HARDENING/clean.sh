#!/bin/bash
#
# LogiCorp Gateway - System Hardening Script
# IronShield Consulting
#
# Purpose: Harden the gateway by disabling unnecessary services,
#          securing SSH configuration, and applying secure defaults.
#
# Usage: Run as root on the target gateway
#   sudo bash clean.sh
#

set -euo pipefail

echo "=== LogiCorp Gateway - System Hardening ==="
echo "[*] Starting system hardening..."

# --- Package Updates ---
echo "[+] Updating package lists..."
apt-get update -qq

# --- Disable Unnecessary Services ---
echo "[+] Disabling unnecessary services..."

# List of services to disable (common attack surface reducers)
SERVICES_TO_DISABLE=(
    "apache2"
    "nginx"
    "cups"
    "avahi-daemon"
    "bluetooth"
)

for svc in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "  [-] Stopping and disabling: $svc"
        systemctl stop "$svc"
        systemctl disable "$svc"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        echo "  [-] Disabling: $svc"
        systemctl disable "$svc"
    else
        echo "  [.] Not found or already disabled: $svc"
    fi
done

# --- Harden SSH Configuration ---
echo "[+] Hardening SSH configuration..."

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)

# Apply secure SSH settings
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/^#\?AllowAgentForwarding.*/AllowAgentForwarding no/' /etc/ssh/sshd_config
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config

# Ensure settings exist if they weren't in the file
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# Validate SSH config before restarting
echo "[+] Validating SSH configuration..."
sshd -t
if [ $? -eq 0 ]; then
    echo "[+] SSH configuration valid. Restarting sshd..."
    systemctl restart sshd
else
    echo "[!] SSH configuration invalid! Restoring backup..."
    cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config 2>/dev/null
    systemctl restart sshd
    exit 1
fi

# --- Secure Kernel Parameters ---
echo "[+] Applying secure kernel parameters..."

# Disable ICMP redirects (prevent MITM routing attacks)
sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null
sysctl -w net.ipv4.conf.default.accept_redirects=0 > /dev/null
sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null

# Disable source routing (prevent IP spoofing)
sysctl -w net.ipv4.conf.all.accept_source_route=0 > /dev/null

# Enable SYN flood protection
sysctl -w net.ipv4.tcp_syncookies=1 > /dev/null

# Log martian packets (packets with impossible addresses)
sysctl -w net.ipv4.conf.all.log_martians=1 > /dev/null

# --- File Permissions ---
echo "[+] Securing file permissions..."
chmod 600 /etc/ssh/sshd_config
chmod 700 /root/.ssh 2>/dev/null || true
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true

# --- Remove Unnecessary Packages ---
echo "[+] Removing unnecessary packages..."
apt-get autoremove -y -qq 2>/dev/null || true

echo ""
echo "=== System Hardening Complete ==="
echo "[!] IMPORTANT: Verify SSH access before closing this session!"
echo "[!] Test: ssh -i <key> student@<ip> from another terminal"
