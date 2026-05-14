#!/bin/bash
# System Hardening Script - Nexus Financial
# Applies CIS-based hardening to Ubuntu 20.04+
# Idempotent: safe to run multiple times

set -euo pipefail

LOG="/var/log/nexus_hardening.log"
echo "Starting system hardening" | tee -a "$LOG"

# 1. SYSTEM UPDATES
echo "Applying system updates..." | tee -a "$LOG"
apt-get update -qq
apt-get upgrade -y -qq
apt-get autoremove -y -qq
echo "System updated" | tee -a "$LOG"

# 2. SSH HARDENING
echo "Hardening SSH configuration..." | tee -a "$LOG"
SSHD_CONF="/etc/ssh/sshd_config"
[ ! -f "${SSHD_CONF}.orig" ] && cp "$SSHD_CONF" "${SSHD_CONF}.orig"

set_sshd() {
    local key="$1" val="$2"
    grep -qE "^#?${key}" "$SSHD_CONF" \
        && sed -i "s|^#\?${key}.*|${key} ${val}|" "$SSHD_CONF" \
        || echo "${key} ${val}" >> "$SSHD_CONF"
}

set_sshd PermitRootLogin no
set_sshd PasswordAuthentication no
set_sshd PubkeyAuthentication yes
set_sshd X11Forwarding no
set_sshd MaxAuthTries 3
set_sshd LoginGraceTime 30
set_sshd AllowAgentForwarding no
set_sshd AllowTcpForwarding no
set_sshd PermitEmptyPasswords no
set_sshd ClientAliveInterval 300
set_sshd ClientAliveCountMax 2
set_sshd LogLevel VERBOSE

cat > /etc/ssh/banner << 'EOF'
NEXUS FINANCIAL - AUTHORIZED ACCESS ONLY
All sessions are monitored and logged.
Unauthorized access is prohibited and will be prosecuted.
EOF
set_sshd Banner /etc/ssh/banner

systemctl restart ssh
echo "SSH hardened: PermitRootLogin=no PasswordAuthentication=no" | tee -a "$LOG"

# 3. KERNEL HARDENING
echo "Applying kernel hardening parameters..." | tee -a "$LOG"
SYSCTL_CONF="/etc/sysctl.d/99-nexus-hardening.conf"
cat > "$SYSCTL_CONF" << 'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.ip_forward = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rfc1337 = 1
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
EOF
sysctl -p "$SYSCTL_CONF"
echo "Kernel parameters applied" | tee -a "$LOG"

# 4. DISABLE UNNECESSARY SERVICES
echo "Disabling unnecessary services..." | tee -a "$LOG"
for svc in telnet rsh-server rlogin-server tftp-server xinetd avahi-daemon cups; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q "enabled"; then
        systemctl disable --now "$svc" 2>/dev/null || true
        echo "Disabled: $svc" | tee -a "$LOG"
    fi
done

# 5. INSTALL SECURITY TOOLS
echo "Installing security tools..." | tee -a "$LOG"
apt-get install -y -qq fail2ban auditd audispd-plugins unattended-upgrades libpam-pwquality rkhunter acl ufw
echo "Security tools installed" | tee -a "$LOG"

# 6. FAIL2BAN
echo "Configuring fail2ban..." | tee -a "$LOG"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd

[sshd]
enabled  = true
port     = ssh
maxretry = 3
bantime  = 86400
EOF
systemctl enable fail2ban
systemctl restart fail2ban
echo "Fail2ban configured" | tee -a "$LOG"

# 7. PASSWORD POLICY (PAM pwquality)
echo "Configuring password policy..." | tee -a "$LOG"
cat > /etc/security/pwquality.conf << 'EOF'
minlen = 16
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
reject_username = yes
dictcheck = 1
EOF
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
echo "Password policy configured" | tee -a "$LOG"

# 8. AUTOMATIC SECURITY UPDATES
echo "Enabling automatic security updates..." | tee -a "$LOG"
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
echo "Automatic updates enabled" | tee -a "$LOG"

# 9. FILESYSTEM PERMISSIONS
echo "Setting filesystem permissions..." | tee -a "$LOG"
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/gshadow
chmod 700 /root
[ -d /root/.ssh ] && chmod 700 /root/.ssh

# Restrict cron to root
echo "root" > /etc/cron.allow
echo "" > /etc/cron.deny 2>/dev/null || true
echo "Filesystem permissions set" | tee -a "$LOG"

# 10. DISABLE USB STORAGE
echo "Disabling USB storage..." | tee -a "$LOG"
echo "install usb-storage /bin/true" > /etc/modprobe.d/disable-usb-storage.conf
echo "blacklist usb-storage" >> /etc/modprobe.d/disable-usb-storage.conf
echo "USB storage disabled" | tee -a "$LOG"

echo "System hardening complete" | tee -a "$LOG"
