#!/bin/bash
#
# LogiCorp Gateway - VPN Setup Script
# IronShield Consulting
#
# Purpose: Deploy Wireguard VPN on the gateway server.
#          Generates keys, configures server, enables at boot.
#
# Usage: Run as root on the target gateway
#   sudo bash vpn_setup.sh
#

set -euo pipefail

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
VPN_SUBNET="10.200.0"
SERVER_IP="${VPN_SUBNET}.1/24"
LISTEN_PORT="51820"

echo "=== LogiCorp Gateway - VPN Setup ==="

# --- Install Wireguard ---
echo "[+] Installing Wireguard..."
apt-get update -qq
apt-get install -y -qq wireguard wireguard-tools

# --- Create Wireguard Directory ---
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

# --- Generate Server Keypair ---
echo "[+] Generating server keypair..."
wg genkey | tee "${WG_DIR}/server_private" | wg pubkey > "${WG_DIR}/server_public"
chmod 600 "${WG_DIR}/server_private"

SERVER_PRIVKEY=$(cat "${WG_DIR}/server_private")
SERVER_PUBKEY=$(cat "${WG_DIR}/server_public")

echo "[*] Server public key: ${SERVER_PUBKEY}"

# --- Generate Client Keypairs ---
echo "[+] Generating IT Admin client keypair..."
wg genkey | tee "${WG_DIR}/client_private" | wg pubkey > "${WG_DIR}/client_public"
chmod 600 "${WG_DIR}/client_private"

CLIENT_PRIVKEY=$(cat "${WG_DIR}/client_private")
CLIENT_PUBKEY=$(cat "${WG_DIR}/client_public")

echo "[*] IT Admin public key: ${CLIENT_PUBKEY}"

echo "[+] Generating Finance client keypair..."
wg genkey | tee "${WG_DIR}/finance_private" | wg pubkey > "${WG_DIR}/finance_public"
chmod 600 "${WG_DIR}/finance_private"

FINANCE_PRIVKEY=$(cat "${WG_DIR}/finance_private")
FINANCE_PUBKEY=$(cat "${WG_DIR}/finance_public")

echo "[*] Finance public key: ${FINANCE_PUBKEY}"

# --- Create Server Configuration ---
echo "[+] Creating server configuration..."
cat > "${WG_DIR}/${WG_INTERFACE}.conf" <<EOF
[Interface]
Address = ${SERVER_IP}
ListenPort = ${LISTEN_PORT}
PrivateKey = ${SERVER_PRIVKEY}

# IT Admin
[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = ${VPN_SUBNET}.2/32

# Finance User
[Peer]
PublicKey = ${FINANCE_PUBKEY}
AllowedIPs = ${VPN_SUBNET}.3/32
EOF

chmod 600 "${WG_DIR}/${WG_INTERFACE}.conf"

# --- Create Client Configuration Files ---
echo "[+] Creating client configuration files..."

# Detect server's public IP
SERVER_ENDPOINT=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$SERVER_ENDPOINT" ]; then
    SERVER_ENDPOINT="<SERVER_PUBLIC_IP>"
    echo "[!] Could not detect public IP. Replace <SERVER_PUBLIC_IP> in client configs."
fi

# IT Admin client config
cat > "${WG_DIR}/client.conf" <<EOF
[Interface]
Address = ${VPN_SUBNET}.2/24
PrivateKey = ${CLIENT_PRIVKEY}

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${SERVER_ENDPOINT}:${LISTEN_PORT}
AllowedIPs = ${VPN_SUBNET}.0/24
PersistentKeepalive = 25
EOF

# Finance client config
cat > "${WG_DIR}/finance.conf" <<EOF
[Interface]
Address = ${VPN_SUBNET}.3/24
PrivateKey = ${FINANCE_PRIVKEY}

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${SERVER_ENDPOINT}:${LISTEN_PORT}
AllowedIPs = ${VPN_SUBNET}.0/24
PersistentKeepalive = 25
EOF

chmod 600 "${WG_DIR}/client.conf" "${WG_DIR}/finance.conf"

# --- Start Wireguard ---
echo "[+] Starting Wireguard interface..."

# Stop if already running
wg-quick down "$WG_INTERFACE" 2>/dev/null || true

wg-quick up "$WG_INTERFACE"

# --- Enable at Boot ---
echo "[+] Enabling Wireguard at boot..."
systemctl enable "wg-quick@${WG_INTERFACE}"

# --- Display Status ---
echo ""
echo "=== VPN Status ==="
wg show "$WG_INTERFACE"
echo ""

echo "=== Client Configuration Files ==="
echo "[*] IT Admin config: ${WG_DIR}/client.conf"
echo "[*] Finance config:  ${WG_DIR}/finance.conf"
echo ""
echo "[!] IMPORTANT: Copy client configs to respective machines:"
echo "    scp ${WG_DIR}/client.conf admin@workstation:/etc/wireguard/"
echo "    scp ${WG_DIR}/finance.conf finance@workstation:/etc/wireguard/"
echo ""
echo "[!] On client machines, start VPN with:"
echo "    sudo wg-quick up client    (IT Admin)"
echo "    sudo wg-quick up finance   (Finance)"
echo ""
echo "[!] Verify tunnel: ping ${VPN_SUBNET}.1"
echo ""
echo "=== VPN Setup Complete ==="
