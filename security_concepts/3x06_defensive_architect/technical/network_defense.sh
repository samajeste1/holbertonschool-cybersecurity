#!/bin/bash
# Network Defense Script — Nexus Financial
# Implements UFW Default Deny + micro-segmentation rules
# Idempotent: safe to run multiple times
# CRITICAL: Closes port 5432 open to 0.0.0.0/0

set -euo pipefail

LOG="/var/log/nexus_network.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting network defense configuration" | tee -a "$LOG"

# ──────────────────────────────────────────────
# CONFIGURATION — EDIT THESE FOR YOUR ENVIRONMENT
# ──────────────────────────────────────────────
BASTION_IP="${BASTION_IP:-10.0.0.10}"         # Bastion host IP for SSH access
WEB_SERVER_IP="${WEB_SERVER_IP:-10.0.1.20}"   # Web/app server IP (only one allowed to reach DB)
LOG_SERVER_IP="${LOG_SERVER_IP:-10.0.0.50}"   # Centralized log server IP
VPN_SUBNET="${VPN_SUBNET:-10.8.0.0/24}"       # WireGuard VPN subnet for remote team

echo "[*] Configuration:" | tee -a "$LOG"
echo "    Bastion IP:    $BASTION_IP" | tee -a "$LOG"
echo "    Web Server IP: $WEB_SERVER_IP" | tee -a "$LOG"
echo "    Log Server IP: $LOG_SERVER_IP" | tee -a "$LOG"
echo "    VPN Subnet:    $VPN_SUBNET" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 1. INSTALL UFW IF MISSING
# ──────────────────────────────────────────────
if ! command -v ufw > /dev/null 2>&1; then
    echo "[*] Installing ufw..." | tee -a "$LOG"
    apt-get install -y -qq ufw
fi

# ──────────────────────────────────────────────
# 2. RESET UFW TO CLEAN STATE (idempotent reset)
# ──────────────────────────────────────────────
echo "[*] Resetting UFW to clean state..." | tee -a "$LOG"
ufw --force reset
echo "[+] UFW reset complete" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 3. DEFAULT DENY POLICY
# ──────────────────────────────────────────────
echo "[*] Setting default deny policy..." | tee -a "$LOG"
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
echo "[+] Default: DENY ALL (incoming, outgoing, routed)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 4. LOOPBACK (required for system function)
# ──────────────────────────────────────────────
ufw allow in on lo
ufw allow out on lo
echo "[+] Loopback interface allowed" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 5. SSH — RESTRICTED TO BASTION ONLY
# Rule: SSH from internet is BLOCKED. Only bastion can SSH in.
# ──────────────────────────────────────────────
echo "[*] Configuring SSH rules (bastion only)..." | tee -a "$LOG"
ufw allow in from "$BASTION_IP" to any port 22 proto tcp comment "SSH from bastion only"
echo "[+] SSH: allowed from bastion ($BASTION_IP) only" | tee -a "$LOG"
echo "[+] SSH: BLOCKED from all other sources (including 0.0.0.0/0)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 6. HTTPS — PUBLIC WEB ACCESS
# ──────────────────────────────────────────────
echo "[*] Configuring HTTPS rules..." | tee -a "$LOG"
ufw allow in to any port 443 proto tcp comment "HTTPS public web"
ufw allow out to any port 443 proto tcp comment "HTTPS outbound"
echo "[+] HTTPS (443): allowed from internet" | tee -a "$LOG"

# HTTP redirect (optional — redirect to HTTPS, do not serve content)
ufw allow in to any port 80 proto tcp comment "HTTP redirect to HTTPS only"
echo "[+] HTTP (80): allowed for redirect only" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 7. DATABASE — CLOSED TO INTERNET, WEB SERVER ONLY
# CRITICAL FIX: port 5432 was open to 0.0.0.0/0
# ──────────────────────────────────────────────
echo "[*] CRITICAL: Closing PostgreSQL port to internet..." | tee -a "$LOG"

# Explicitly deny 5432 from all sources first
ufw deny in to any port 5432 proto tcp comment "BLOCK DB from internet — CRITICAL"

# Then allow only from web server private IP
ufw allow in from "$WEB_SERVER_IP" to any port 5432 proto tcp comment "DB: web server only"
echo "[+] PostgreSQL (5432): BLOCKED from internet (0.0.0.0/0 CLOSED)" | tee -a "$LOG"
echo "[+] PostgreSQL (5432): allowed from web server ($WEB_SERVER_IP) only" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 8. DNS (required for system and application function)
# ──────────────────────────────────────────────
ufw allow out to any port 53 proto udp comment "DNS queries"
ufw allow out to any port 53 proto tcp comment "DNS queries TCP"
echo "[+] DNS outbound allowed" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 9. NTP (time synchronization — required for log integrity)
# ──────────────────────────────────────────────
ufw allow out to any port 123 proto udp comment "NTP time sync"
echo "[+] NTP outbound allowed" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 10. CENTRALIZED LOGGING — OUTBOUND TO LOG SERVER
# ──────────────────────────────────────────────
echo "[*] Configuring log forwarding rules..." | tee -a "$LOG"
ufw allow out to "$LOG_SERVER_IP" port 514 proto udp comment "Syslog to centralized server"
ufw allow out to "$LOG_SERVER_IP" port 514 proto tcp comment "Syslog TCP to centralized server"
ufw allow out to "$LOG_SERVER_IP" port 6514 proto tcp comment "Encrypted syslog TLS"
echo "[+] Log forwarding: allowed to log server ($LOG_SERVER_IP)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 11. VPN — FOR REMOTE BALI TEAM
# WireGuard VPN replaces direct DB access from Bali
# ──────────────────────────────────────────────
echo "[*] Configuring VPN access for remote team..." | tee -a "$LOG"
ufw allow in to any port 51820 proto udp comment "WireGuard VPN"
ufw allow in from "$VPN_SUBNET" to any port 443 proto tcp comment "VPN clients to HTTPS"
echo "[+] WireGuard VPN (51820/UDP): allowed" | tee -a "$LOG"
echo "[+] VPN subnet ($VPN_SUBNET): allowed to HTTPS only (not direct DB)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 12. APT UPDATES (outbound HTTPS/HTTP to package servers)
# ──────────────────────────────────────────────
ufw allow out to any port 80 proto tcp comment "APT updates HTTP"
ufw allow out to any port 443 proto tcp comment "APT updates HTTPS"
echo "[+] APT update traffic allowed outbound" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 13. DISABLE UNUSED SWITCH PORTS (logical — via config note)
# Physical switch port disabling must be done on the switch itself
# ──────────────────────────────────────────────
echo "[*] Note: Unused physical switch ports must be disabled on the managed switch." | tee -a "$LOG"
echo "         Use 'switchport shutdown' on Cisco or equivalent for unmanaged ports." | tee -a "$LOG"

# ──────────────────────────────────────────────
# 14. ENABLE UFW WITH LOGGING
# ──────────────────────────────────────────────
echo "[*] Enabling UFW with logging..." | tee -a "$LOG"
ufw logging on
ufw logging high
echo "y" | ufw enable
echo "[+] UFW enabled with HIGH logging" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 15. VERIFY CONFIGURATION
# ──────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "=== UFW RULES SUMMARY ===" | tee -a "$LOG"
ufw status verbose | tee -a "$LOG"
echo "=========================" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 16. CRITICAL VERIFICATION — DB PORT CHECK
# ──────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "[*] Verifying PostgreSQL port 5432 is blocked from internet..." | tee -a "$LOG"
if ufw status | grep -q "5432.*ALLOW.*Anywhere"; then
    echo "[!!!] CRITICAL: Port 5432 is still open to the internet! Review rules immediately." | tee -a "$LOG"
    exit 1
else
    echo "[+] VERIFIED: Port 5432 is NOT openly accessible from internet" | tee -a "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Network defense configuration complete" | tee -a "$LOG"
