#!/bin/bash
# System Hardening Script — Nexus Financial
# Idempotent: safe to run multiple times
# Target: Ubuntu 20.04+

set -euo pipefail

LOG="/var/log/nexus_hardening.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting system hardening" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 1. SYSTEM UPDATES
# ──────────────────────────────────────────────
echo "[*] Applying system updates..." | tee -a "$LOG"
apt-get update -qq
apt-get upgrade -y -qq
apt-get autoremove -y -qq

# ──────────────────────────────────────────────
# 2. SSH HARDENING
# ──────────────────────────────────────────────
echo "[*] Hardening SSH configuration..." | tee -a "$LOG"
SSHD_CONF="/etc/ssh/sshd_config"

# Backup original config if not already backed up
[ ! -f "${SSHD_CONF}.orig" ] && cp "$SSHD_CONF" "${SSHD_CONF}.orig"

configure_sshd() {
    local key="$1"
    local value="$2"
    if grep -qE "^#?${key}" "$SSHD_CONF"; then
        sed -i "s|^#\?${key}.*|${key} ${value}|" "$SSHD_CONF"
    else
        echo "${key} ${value}" >> "$SSHD_CONF"
    fi
}

configure_sshd "PermitRootLogin" "no"
configure_sshd "PasswordAuthentication" "no"
configure_sshd "PubkeyAuthentication" "yes"
configure_sshd "AuthorizedKeysFile" ".ssh/authorized_keys"
configure_sshd "X11Forwarding" "no"
configure_sshd "MaxAuthTries" "3"
configure_sshd "LoginGraceTime" "30"
configure_sshd "AllowAgentForwarding" "no"
configure_sshd "AllowTcpForwarding" "no"
configure_sshd "PermitEmptyPasswords" "no"
configure_sshd "ClientAliveInterval" "300"
configure_sshd "ClientAliveCountMax" "2"
configure_sshd "Protocol" "2"
configure_sshd "LogLevel" "VERBOSE"
configure_sshd "Banner" "/etc/ssh/banner"

# SSH warning banner
cat > /etc/ssh/banner << 'EOF'
*********************************************************************
* NEXUS FINANCIAL — AUTHORIZED ACCESS ONLY                         *
* All sessions are monitored and logged.                           *
* Unauthorized access is prohibited and will be prosecuted.        *
*********************************************************************
EOF

systemctl restart ssh
echo "[+] SSH hardened" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 3. KERNEL / SYSCTL HARDENING
# ──────────────────────────────────────────────
echo "[*] Applying kernel hardening parameters..." | tee -a "$LOG"
SYSCTL_CONF="/etc/sysctl.d/99-nexus-hardening.conf"

cat > "$SYSCTL_CONF" << 'EOF'
# Nexus Financial — Kernel Hardening

# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable IP forwarding (not a router)
net.ipv4.ip_forward = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable ping
net.ipv4.icmp_echo_ignore_all = 1

# Protect against time-wait assassination
net.ipv4.tcp_rfc1337 = 1

# Randomize virtual address space (ASLR)
kernel.randomize_va_space = 2

# Restrict dmesg to root
kernel.dmesg_restrict = 1

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# Prevent core dumps from setuid programs
fs.suid_dumpable = 0

# Restrict /proc
kernel.kptr_restrict = 2
EOF

sysctl -p "$SYSCTL_CONF"
echo "[+] Kernel parameters applied" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 4. REMOVE UNNECESSARY SERVICES
# ──────────────────────────────────────────────
echo "[*] Disabling unnecessary services..." | tee -a "$LOG"
UNNECESSARY_SERVICES="telnet rsh-server rlogin-server tftp-server xinetd avahi-daemon cups"
for svc in $UNNECESSARY_SERVICES; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q "enabled"; then
        systemctl disable --now "$svc" 2>/dev/null || true
        echo "[+] Disabled: $svc" | tee -a "$LOG"
    fi
done

# ──────────────────────────────────────────────
# 5. FILESYSTEM SECURITY
# ──────────────────────────────────────────────
echo "[*] Configuring filesystem security..." | tee -a "$LOG"

# Secure /tmp
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs rw,nosuid,nodev,noexec,relatime 0 0" >> /etc/fstab
fi

# Set correct permissions on sensitive files
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/gshadow
chmod 700 /root
chmod 700 /root/.ssh 2>/dev/null || true

# Restrict cron to root only
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly
echo "root" > /etc/cron.allow
echo "" > /etc/cron.deny 2>/dev/null || true
echo "[+] Filesystem permissions set" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 6. INSTALL SECURITY TOOLS
# ──────────────────────────────────────────────
echo "[*] Installing security tools..." | tee -a "$LOG"
apt-get install -y -qq \
    fail2ban \
    auditd \
    audispd-plugins \
    unattended-upgrades \
    libpam-pwquality \
    rkhunter \
    acl \
    ufw

echo "[+] Security tools installed" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 7. FAIL2BAN CONFIGURATION
# ──────────────────────────────────────────────
echo "[*] Configuring fail2ban..." | tee -a "$LOG"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 86400
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "[+] Fail2ban configured and started" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 8. PASSWORD POLICY
# ──────────────────────────────────────────────
echo "[*] Configuring password policy..." | tee -a "$LOG"
PAM_PWQUALITY="/etc/security/pwquality.conf"
cat > "$PAM_PWQUALITY" << 'EOF'
minlen = 16
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
reject_username = yes
dictcheck = 1
EOF

# Password expiry defaults
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
echo "[+] Password policy configured" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 9. ENABLE UNATTENDED SECURITY UPGRADES
# ──────────────────────────────────────────────
echo "[*] Enabling automatic security updates..." | tee -a "$LOG"
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
echo "[+] Automatic security updates enabled" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 10. DISABLE USB STORAGE
# ──────────────────────────────────────────────
echo "[*] Disabling USB storage..." | tee -a "$LOG"
echo "install usb-storage /bin/true" > /etc/modprobe.d/disable-usb-storage.conf
echo "blacklist usb-storage" >> /etc/modprobe.d/disable-usb-storage.conf
echo "[+] USB storage disabled" | tee -a "$LOG"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Hardening complete. Review $LOG for details." | tee -a "$LOG"
