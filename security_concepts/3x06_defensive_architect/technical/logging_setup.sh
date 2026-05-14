#!/bin/bash
# Logging Setup Script — Nexus Financial
# Configures rsyslog (centralized forwarding) + auditd (file/command monitoring)
# Makes audit config immutable until reboot
# Idempotent: safe to run multiple times

set -euo pipefail

LOG="/var/log/nexus_logging_setup.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting logging configuration" | tee -a "$LOG"

# ──────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────
CENTRAL_LOG_SERVER="${CENTRAL_LOG_SERVER:-10.0.0.50}"
CENTRAL_LOG_PORT="${CENTRAL_LOG_PORT:-514}"

echo "[*] Log server: $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 1. INSTALL REQUIRED PACKAGES
# ──────────────────────────────────────────────
echo "[*] Installing auditd and rsyslog..." | tee -a "$LOG"
apt-get update -qq
apt-get install -y -qq auditd audispd-plugins rsyslog
echo "[+] Packages installed" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 2. RSYSLOG — CENTRALIZED LOG FORWARDING
# ──────────────────────────────────────────────
echo "[*] Configuring rsyslog for centralized forwarding..." | tee -a "$LOG"
RSYSLOG_NEXUS="/etc/rsyslog.d/99-nexus-forward.conf"

cat > "$RSYSLOG_NEXUS" << RSYSLOG_EOF
# Nexus Financial — Centralized Log Forwarding
# All critical logs forwarded to $CENTRAL_LOG_SERVER

# Load TCP forwarding module
\$ModLoad imtcp
\$ModLoad imudp

# Template: structured format for SIEM ingestion
\$template NexusFormat,"%TIMESTAMP:::date-rfc3339% %HOSTNAME% %syslogtag%%msg%\n"

# Forward ALL logs to central server (TCP for reliability)
*.* action(type="omfwd"
    target="$CENTRAL_LOG_SERVER"
    port="$CENTRAL_LOG_PORT"
    protocol="tcp"
    action.resumeRetryCount="-1"
    queue.type="LinkedList"
    queue.size="10000"
    queue.filename="fwd_backup"
    queue.saveOnShutdown="on"
    template="NexusFormat"
)

# Critical security events — also forward via UDP as backup
auth,authpriv.* action(type="omfwd"
    target="$CENTRAL_LOG_SERVER"
    port="$CENTRAL_LOG_PORT"
    protocol="udp"
    template="NexusFormat"
)

# Keep local copies
auth,authpriv.*         /var/log/auth.log
kern.*                  /var/log/kern.log
*.emerg                 :omusrmsg:*
RSYSLOG_EOF

# Restart rsyslog to apply
systemctl restart rsyslog
systemctl enable rsyslog
echo "[+] Rsyslog configured to forward to $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 3. AUDITD — MONITOR SENSITIVE FILES AND COMMANDS
# ──────────────────────────────────────────────
echo "[*] Configuring auditd rules..." | tee -a "$LOG"
AUDIT_RULES="/etc/audit/rules.d/nexus.rules"

cat > "$AUDIT_RULES" << 'AUDIT_EOF'
# Nexus Financial — Audit Rules
# Monitors sensitive file access and privileged command execution

# ── Delete existing rules and start clean ──
-D

# ── Buffer size (increase for high-activity systems) ──
-b 8192

# ── Failure mode: 2 = panic, 1 = printk ──
-f 1

# ════════════════════════════════
# IDENTITY AND AUTHENTICATION
# ════════════════════════════════

# Monitor changes to user accounts
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity

# Monitor sudoers changes
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/sudoers.d/ -p wa -k sudoers_change

# Monitor SSH authorized keys
-w /root/.ssh/ -p wa -k ssh_keys
-w /home/ -p wa -k ssh_keys

# ════════════════════════════════
# SSH AND AUTHENTICATION EVENTS
# ════════════════════════════════

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# ════════════════════════════════
# PRIVILEGED COMMAND EXECUTION
# ════════════════════════════════

# Monitor sudo usage
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged_exec
-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged_exec

# Monitor su and sudo specifically
-w /usr/bin/sudo -p x -k privileged_sudo
-w /bin/su -p x -k privileged_su

# Monitor setuid/setgid executables
-a always,exit -F arch=b64 -S setuid -S setgid -k setuid_setgid
-a always,exit -F arch=b32 -S setuid -S setgid -k setuid_setgid

# ════════════════════════════════
# FILESYSTEM AND CONFIG CHANGES
# ════════════════════════════════

# Monitor critical config directories
-w /etc/ -p wa -k config_change
-w /var/www/ -p wa -k web_content_change

# Monitor network config
-w /etc/hosts -p wa -k network_config
-w /etc/resolv.conf -p wa -k network_config
-w /etc/iptables/ -p wa -k firewall_change

# Monitor cron (persistence mechanism)
-w /etc/cron.d/ -p wa -k cron_change
-w /etc/cron.daily/ -p wa -k cron_change
-w /etc/crontab -p wa -k cron_change
-w /var/spool/cron/ -p wa -k cron_change

# Monitor systemd service files (persistence)
-w /etc/systemd/system/ -p wa -k systemd_change
-w /lib/systemd/system/ -p wa -k systemd_change

# ════════════════════════════════
# DANGEROUS COMMANDS
# ════════════════════════════════

# Monitor deletion commands
-a always,exit -F arch=b64 -S unlinkat -S rename -S renameat -k delete
-a always,exit -F arch=b32 -S unlinkat -S rename -S renameat -k delete

# Monitor chmod/chown (privilege escalation via permissions)
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -k permissions_change
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -k permissions_change
-a always,exit -F arch=b64 -S chown -S fchown -S lchown -k ownership_change
-a always,exit -F arch=b32 -S chown -S fchown -S lchown -k ownership_change

# Monitor module loading (rootkit installation)
-w /sbin/insmod -p x -k module_load
-w /sbin/rmmod -p x -k module_load
-w /sbin/modprobe -p x -k module_load
-a always,exit -F arch=b64 -S init_module -S delete_module -k module_load

# ════════════════════════════════
# NETWORK EVENTS
# ════════════════════════════════

# Monitor network socket creation (outbound C2, data exfil)
-a always,exit -F arch=b64 -S socket -F a0=2 -k network_socket
-a always,exit -F arch=b32 -S socket -F a0=2 -k network_socket

# ════════════════════════════════
# DATABASE ACCESS
# ════════════════════════════════

# Monitor PostgreSQL config and data directory
-w /etc/postgresql/ -p wa -k db_config
-w /var/lib/postgresql/ -p rwa -k db_access

# ════════════════════════════════
# MAKE RULES IMMUTABLE UNTIL REBOOT
# ════════════════════════════════

# This must be the LAST line — locks all rules until reboot
-e 2
AUDIT_EOF

echo "[+] Audit rules written to $AUDIT_RULES" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 4. AUDITD MAIN CONFIGURATION
# ──────────────────────────────────────────────
echo "[*] Configuring auditd main settings..." | tee -a "$LOG"
AUDITD_CONF="/etc/audit/auditd.conf"

configure_auditd() {
    local key="$1"
    local value="$2"
    if grep -qE "^${key}" "$AUDITD_CONF"; then
        sed -i "s|^${key}.*|${key} = ${value}|" "$AUDITD_CONF"
    else
        echo "${key} = ${value}" >> "$AUDITD_CONF"
    fi
}

configure_auditd "log_file" "/var/log/audit/audit.log"
configure_auditd "log_format" "ENRICHED"
configure_auditd "max_log_file" "100"
configure_auditd "max_log_file_action" "ROTATE"
configure_auditd "num_logs" "10"
configure_auditd "space_left" "500"
configure_auditd "space_left_action" "SYSLOG"
configure_auditd "admin_space_left" "100"
configure_auditd "admin_space_left_action" "HALT"
configure_auditd "disk_full_action" "HALT"
configure_auditd "disk_error_action" "HALT"

echo "[+] Auditd configuration updated" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 5. CONFIGURE AUDISP TO FORWARD TO SYSLOG (then to central server)
# ──────────────────────────────────────────────
echo "[*] Configuring audisp-syslog plugin..." | tee -a "$LOG"
AUDISP_SYSLOG="/etc/audit/plugins.d/syslog.conf"
if [ -f "$AUDISP_SYSLOG" ]; then
    sed -i 's/^active.*/active = yes/' "$AUDISP_SYSLOG"
else
    cat > "$AUDISP_SYSLOG" << 'AUDISP_EOF'
active = yes
direction = out
path = builtin_syslog
type = builtin
args = LOG_INFO
format = string
AUDISP_EOF
fi
echo "[+] Audisp-syslog plugin enabled (audit events → syslog → central server)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 6. START AND ENABLE AUDITD
# ──────────────────────────────────────────────
echo "[*] Starting and enabling auditd..." | tee -a "$LOG"
systemctl enable auditd
systemctl restart auditd
echo "[+] Auditd started and enabled" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 7. LOAD AUDIT RULES
# ──────────────────────────────────────────────
echo "[*] Loading audit rules..." | tee -a "$LOG"
augenrules --load 2>/dev/null || auditctl -R "$AUDIT_RULES"
echo "[+] Audit rules loaded" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 8. VERIFY IMMUTABILITY FLAG
# ──────────────────────────────────────────────
echo "[*] Verifying audit rules are immutable..." | tee -a "$LOG"
if auditctl -l 2>/dev/null | grep -q "^-e 2"; then
    echo "[+] VERIFIED: Audit rules are IMMUTABLE (require reboot to change)" | tee -a "$LOG"
else
    echo "[!] Warning: Could not confirm immutability flag (-e 2). Check auditctl -l output." | tee -a "$LOG"
fi

# ──────────────────────────────────────────────
# 9. CONFIGURE LOG ROTATION
# ──────────────────────────────────────────────
echo "[*] Configuring log rotation..." | tee -a "$LOG"
cat > /etc/logrotate.d/nexus-audit << 'LOGROTATE_EOF'
/var/log/audit/audit.log {
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        /sbin/service auditd condrestart 2>/dev/null || true
    endscript
}
LOGROTATE_EOF
echo "[+] Log rotation configured (52 weeks retention)" | tee -a "$LOG"

# ──────────────────────────────────────────────
# 10. VERIFICATION SUMMARY
# ──────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "=== LOGGING SETUP SUMMARY ===" | tee -a "$LOG"
echo "Rsyslog: forwarding to $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"
echo "Auditd: monitoring sensitive files + privileged commands" | tee -a "$LOG"
echo "Audit rules: IMMUTABLE until reboot (-e 2)" | tee -a "$LOG"
echo "Audisp: forwarding audit events to syslog → central server" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Active audit rules:" | tee -a "$LOG"
auditctl -l 2>/dev/null | tee -a "$LOG" || echo "(auditctl -l: run as root to verify)" | tee -a "$LOG"
echo "==============================" | tee -a "$LOG"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging setup complete" | tee -a "$LOG"
