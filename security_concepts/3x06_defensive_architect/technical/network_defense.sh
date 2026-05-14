#!/bin/bash
# Network Defense Script — Nexus Financial
# Implements UFW Default Deny + micro-segmentation
# Idempotent: safe to run multiple times
# CRITICAL: Closes port 5432 open to 0.0.0.0/0

set -euo pipefail

LOG="/var/log/nexus_network.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting network defense configuration" | tee -a "$LOG"

# ──────────────────────────────────────────────
# CONFIGURATION — override via environment variables
# ──────────────────────────────────────────────
BASTION_IP="${BASTION_IP:-192.168.1.10}"         # Bastion host (SSH access only from here)
WEB_SERVER_IP="${WEB_SERVER_IP:-192.168.1.20}"   # Web/app server (only host allowed to reach DB)
LOG_SERVER_IP="${LOG_SERVER_IP:-192.168.1.50}"   # Centralized syslog server
VPN_SUBNET="${VPN_SUBNET:-10.8.0.0/24}"          # WireGuard VPN subnet for remote Bali team

echo "[*] Bastion: $BASTION_IP | WebServer: $WEB_SERVER_IP | LogServer: $LOG_SERVER_IP" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 1. INSTALL UFW IF MISSING
# ──────────────────────────────────────────────
if ! command -v ufw > /dev/null 2>&1; then
    apt-get install -y -qq ufw
fi

# ──────────────────────────────────────────────
# 2. RESET UFW (idempotent clean state)
# ──────────────────────────────────────────────
ufw --force reset
echo "[+] UFW reset to clean state" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 3. DEFAULT DENY POLICY — deny everything by default
# ──────────────────────────────────────────────
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
echo "[+] Default policy: DENY ALL" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 4. LOOPBACK — required for local processes
# ──────────────────────────────────────────────
ufw allow in on lo
ufw allow out on lo

# ──────────────────────────────────────────────
# 5. SSH — bastion host only
# Port 22 is BLOCKED from internet; only bastion IP allowed
# ──────────────────────────────────────────────
ufw allow in from "$BASTION_IP" to any port 22 proto tcp comment "SSH bastion only"
echo "[+] SSH(22): allowed from bastion $BASTION_IP only" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 6. HTTPS/HTTP — public web access
# ──────────────────────────────────────────────
ufw allow in to any port 443 proto tcp comment "HTTPS public"
ufw allow in to any port 80 proto tcp comment "HTTP redirect"
ufw allow out to any port 443 proto tcp comment "HTTPS outbound"
ufw allow out to any port 80 proto tcp comment "HTTP outbound"
echo "[+] HTTP(80) and HTTPS(443): open to internet" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 7. POSTGRESQL 5432 — web server private IP only
# CRITICAL: was previously open to 0.0.0.0/0 — now internal-only
# Default deny already blocks all other sources; only allow web server
# ──────────────────────────────────────────────
ufw allow in from "$WEB_SERVER_IP" to any port 5432 proto tcp comment "DB: webserver only"
echo "[+] PostgreSQL(5432): CLOSED to internet, allowed from $WEB_SERVER_IP only" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 8. WIREGUARD VPN — remote Bali team
# Bali team connects via VPN, then accesses API (HTTPS) — not DB directly
# ──────────────────────────────────────────────
ufw allow in to any port 51820 proto udp comment "WireGuard VPN"
ufw allow in from "$VPN_SUBNET" to any port 443 proto tcp comment "VPN clients HTTPS"
echo "[+] WireGuard VPN(51820/udp): open. VPN subnet HTTPS allowed." | tee -a "$LOG"

# ──────────────────────────────────────────────
# 9. DNS + NTP (required outbound)
# ──────────────────────────────────────────────
ufw allow out to any port 53 proto udp comment "DNS"
ufw allow out to any port 53 proto tcp comment "DNS TCP"
ufw allow out to any port 123 proto udp comment "NTP"

# ──────────────────────────────────────────────
# 10. CENTRALIZED LOGGING — outbound to log server
# ──────────────────────────────────────────────
ufw allow out to "$LOG_SERVER_IP" port 514 proto udp comment "Syslog UDP"
ufw allow out to "$LOG_SERVER_IP" port 514 proto tcp comment "Syslog TCP"
echo "[+] Syslog: forwarding to $LOG_SERVER_IP:514" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 11. ENABLE UFW WITH LOGGING
# ──────────────────────────────────────────────
ufw logging on
ufw logging high
echo "y" | ufw enable
echo "[+] UFW enabled with HIGH logging" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 12. VERIFY — port 5432 must not be open to Anywhere
# ──────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "=== UFW STATUS ===" | tee -a "$LOG"
ufw status verbose | tee -a "$LOG"

if ufw status | grep -qE "5432.*ALLOW IN.*Anywhere$"; then
    echo "[!!!] CRITICAL: Port 5432 still open to internet! Fix immediately." | tee -a "$LOG"
    exit 1
fi
echo "[+] VERIFIED: Port 5432 NOT exposed to internet" | tee -a "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network defense complete" | tee -a "$LOG"
