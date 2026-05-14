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
test -f "${SSHD_CONF}.orig" || cp "$SSHD_CONF" "${SSHD_CONF}.orig"

sed -i 's|^#\?PermitRootLogin.*|PermitRootLogin no|' "$SSHD_CONF"
grep -qE '^PermitRootLogin' "$SSHD_CONF" || echo "PermitRootLogin no" >> "$SSHD_CONF"

sed -i 's|^#\?PasswordAuthentication.*|PasswordAuthentication no|' "$SSHD_CONF"
grep -qE '^PasswordAuthentication' "$SSHD_CONF" || echo "PasswordAuthentication no" >> "$SSHD_CONF"

sed -i 's|^#\?PubkeyAuthentication.*|PubkeyAuthentication yes|' "$SSHD_CONF"
grep -qE '^PubkeyAuthentication' "$SSHD_CONF" || echo "PubkeyAuthentication yes" >> "$SSHD_CONF"

sed -i 's|^#\?X11Forwarding.*|X11Forwarding no|' "$SSHD_CONF"
grep -qE '^X11Forwarding' "$SSHD_CONF" || echo "X11Forwarding no" >> "$SSHD_CONF"

sed -i 's|^#\?MaxAuthTries.*|MaxAuthTries 3|' "$SSHD_CONF"
grep -qE '^MaxAuthTries' "$SSHD_CONF" || echo "MaxAuthTries 3" >> "$SSHD_CONF"

sed -i 's|^#\?LoginGraceTime.*|LoginGraceTime 30|' "$SSHD_CONF"
grep -qE '^LoginGraceTime' "$SSHD_CONF" || echo "LoginGraceTime 30" >> "$SSHD_CONF"

sed -i 's|^#\?AllowAgentForwarding.*|AllowAgentForwarding no|' "$SSHD_CONF"
grep -qE '^AllowAgentForwarding' "$SSHD_CONF" || echo "AllowAgentForwarding no" >> "$SSHD_CONF"

sed -i 's|^#\?AllowTcpForwarding.*|AllowTcpForwarding no|' "$SSHD_CONF"
grep -qE '^AllowTcpForwarding' "$SSHD_CONF" || echo "AllowTcpForwarding no" >> "$SSHD_CONF"

sed -i 's|^#\?PermitEmptyPasswords.*|PermitEmptyPasswords no|' "$SSHD_CONF"
grep -qE '^PermitEmptyPasswords' "$SSHD_CONF" || echo "PermitEmptyPasswords no" >> "$SSHD_CONF"

sed -i 's|^#\?ClientAliveInterval.*|ClientAliveInterval 300|' "$SSHD_CONF"
grep -qE '^ClientAliveInterval' "$SSHD_CONF" || echo "ClientAliveInterval 300" >> "$SSHD_CONF"

sed -i 's|^#\?ClientAliveCountMax.*|ClientAliveCountMax 2|' "$SSHD_CONF"
grep -qE '^ClientAliveCountMax' "$SSHD_CONF" || echo "ClientAliveCountMax 2" >> "$SSHD_CONF"

sed -i 's|^#\?LogLevel.*|LogLevel VERBOSE|' "$SSHD_CONF"
grep -qE '^LogLevel' "$SSHD_CONF" || echo "LogLevel VERBOSE" >> "$SSHD_CONF"

printf 'NEXUS FINANCIAL - AUTHORIZED ACCESS ONLY\n' > /etc/ssh/banner
printf 'All sessions are monitored and logged.\n' >> /etc/ssh/banner
printf 'Unauthorized access is prohibited and will be prosecuted.\n' >> /etc/ssh/banner
sed -i 's|^#\?Banner.*|Banner /etc/ssh/banner|' "$SSHD_CONF"
grep -qE '^Banner' "$SSHD_CONF" || echo "Banner /etc/ssh/banner" >> "$SSHD_CONF"

systemctl restart ssh
echo "SSH hardened: PermitRootLogin no PasswordAuthentication no" | tee -a "$LOG"

# 3. KERNEL HARDENING
echo "Applying kernel hardening parameters..." | tee -a "$LOG"
SYSCTL_CONF="/etc/sysctl.d/99-nexus-hardening.conf"
printf 'net.ipv4.conf.all.rp_filter = 1\n' > "$SYSCTL_CONF"
printf 'net.ipv4.conf.default.rp_filter = 1\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.all.accept_source_route = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.default.accept_source_route = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.all.accept_redirects = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.default.accept_redirects = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv6.conf.all.accept_redirects = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.all.send_redirects = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.ip_forward = 0\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.tcp_syncookies = 1\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.all.log_martians = 1\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.conf.default.log_martians = 1\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.icmp_echo_ignore_broadcasts = 1\n' >> "$SYSCTL_CONF"
printf 'net.ipv4.tcp_rfc1337 = 1\n' >> "$SYSCTL_CONF"
printf 'kernel.randomize_va_space = 2\n' >> "$SYSCTL_CONF"
printf 'kernel.dmesg_restrict = 1\n' >> "$SYSCTL_CONF"
printf 'kernel.yama.ptrace_scope = 1\n' >> "$SYSCTL_CONF"
printf 'fs.suid_dumpable = 0\n' >> "$SYSCTL_CONF"
printf 'kernel.kptr_restrict = 2\n' >> "$SYSCTL_CONF"
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
printf '[DEFAULT]\n' > /etc/fail2ban/jail.local
printf 'bantime  = 3600\n' >> /etc/fail2ban/jail.local
printf 'findtime = 600\n' >> /etc/fail2ban/jail.local
printf 'maxretry = 3\n' >> /etc/fail2ban/jail.local
printf 'backend  = systemd\n' >> /etc/fail2ban/jail.local
printf '\n' >> /etc/fail2ban/jail.local
printf '[sshd]\n' >> /etc/fail2ban/jail.local
printf 'enabled  = true\n' >> /etc/fail2ban/jail.local
printf 'port     = ssh\n' >> /etc/fail2ban/jail.local
printf 'maxretry = 3\n' >> /etc/fail2ban/jail.local
printf 'bantime  = 86400\n' >> /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban
echo "Fail2ban configured" | tee -a "$LOG"

# 7. PASSWORD POLICY (PAM pwquality)
echo "Configuring password policy..." | tee -a "$LOG"
printf 'minlen = 16\n' > /etc/security/pwquality.conf
printf 'dcredit = -1\n' >> /etc/security/pwquality.conf
printf 'ucredit = -1\n' >> /etc/security/pwquality.conf
printf 'lcredit = -1\n' >> /etc/security/pwquality.conf
printf 'ocredit = -1\n' >> /etc/security/pwquality.conf
printf 'maxrepeat = 3\n' >> /etc/security/pwquality.conf
printf 'reject_username = yes\n' >> /etc/security/pwquality.conf
printf 'dictcheck = 1\n' >> /etc/security/pwquality.conf
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
echo "Password policy configured: minlen 16 PASS_MAX_DAYS 90" | tee -a "$LOG"

# 8. AUTOMATIC SECURITY UPDATES
echo "Enabling automatic security updates..." | tee -a "$LOG"
printf 'APT::Periodic::Update-Package-Lists "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
printf 'APT::Periodic::Unattended-Upgrade "1";\n' >> /etc/apt/apt.conf.d/20auto-upgrades
printf 'APT::Periodic::AutocleanInterval "7";\n' >> /etc/apt/apt.conf.d/20auto-upgrades
echo "Automatic updates enabled" | tee -a "$LOG"

# 9. FILESYSTEM PERMISSIONS
echo "Setting filesystem permissions..." | tee -a "$LOG"
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/gshadow
chmod 700 /root
test -d /root/.ssh && chmod 700 /root/.ssh

echo "root" > /etc/cron.allow
printf '' > /etc/cron.deny 2>/dev/null || true
echo "Filesystem permissions set" | tee -a "$LOG"

# 10. DISABLE USB STORAGE
echo "Disabling USB storage..." | tee -a "$LOG"
printf 'install usb-storage /bin/true\n' > /etc/modprobe.d/disable-usb-storage.conf
printf 'blacklist usb-storage\n' >> /etc/modprobe.d/disable-usb-storage.conf
echo "USB storage disabled" | tee -a "$LOG"

echo "System hardening complete" | tee -a "$LOG"
