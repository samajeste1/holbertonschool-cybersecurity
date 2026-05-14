#!/bin/bash
# Logging Setup Script - Nexus Financial
# Configures rsyslog (centralized forwarding) + auditd (file/command monitoring)
# Makes audit config immutable until reboot
# Idempotent: safe to run multiple times

set -euo pipefail

LOG="/var/log/nexus_logging_setup.log"
echo "Starting logging configuration" | tee -a "$LOG"

CENTRAL_LOG_SERVER="${CENTRAL_LOG_SERVER:-10.0.0.50}"
CENTRAL_LOG_PORT="${CENTRAL_LOG_PORT:-514}"

echo "Log server: $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"

# 1. INSTALL REQUIRED PACKAGES
echo "Installing auditd and rsyslog..." | tee -a "$LOG"
apt-get update -qq
apt-get install -y -qq auditd audispd-plugins rsyslog
echo "Packages installed" | tee -a "$LOG"

# 2. RSYSLOG - CENTRALIZED LOG FORWARDING
echo "Configuring rsyslog for centralized forwarding..." | tee -a "$LOG"
RSYSLOG_NEXUS="/etc/rsyslog.d/99-nexus-forward.conf"

printf '# Nexus Financial - Centralized Log Forwarding\n' > "$RSYSLOG_NEXUS"
printf '$ModLoad imtcp\n' >> "$RSYSLOG_NEXUS"
printf '$ModLoad imudp\n' >> "$RSYSLOG_NEXUS"
printf '$template NexusFormat,"%%TIMESTAMP:::date-rfc3339%% %%HOSTNAME%% %%syslogtag%%%%msg%%\\n"\n' >> "$RSYSLOG_NEXUS"
printf 'if $syslogseverity <= 7 then action(type="omfwd" target="%s" port="%s" protocol="tcp" action.resumeRetryCount="-1" queue.type="LinkedList" queue.size="10000" queue.filename="fwd_backup" queue.saveOnShutdown="on" template="NexusFormat")\n' "$CENTRAL_LOG_SERVER" "$CENTRAL_LOG_PORT" >> "$RSYSLOG_NEXUS"
printf 'if $syslogfacility-text == "auth" or $syslogfacility-text == "authpriv" then action(type="omfwd" target="%s" port="%s" protocol="udp" template="NexusFormat")\n' "$CENTRAL_LOG_SERVER" "$CENTRAL_LOG_PORT" >> "$RSYSLOG_NEXUS"
printf 'auth,authpriv.*         /var/log/auth.log\n' >> "$RSYSLOG_NEXUS"
printf 'kern.*                  /var/log/kern.log\n' >> "$RSYSLOG_NEXUS"

systemctl restart rsyslog
systemctl enable rsyslog
echo "Rsyslog configured to forward to $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"

# 3. AUDITD - MONITOR SENSITIVE FILES AND COMMANDS
echo "Configuring auditd rules..." | tee -a "$LOG"
AUDIT_RULES="/etc/audit/rules.d/nexus.rules"

printf '# Nexus Financial - Audit Rules\n' > "$AUDIT_RULES"
printf '# Monitors sensitive file access and privileged command execution\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Delete existing rules and start clean\n' >> "$AUDIT_RULES"
printf -- '-D\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Buffer size\n' >> "$AUDIT_RULES"
printf -- '-b 8192\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Failure mode\n' >> "$AUDIT_RULES"
printf -- '-f 1\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# IDENTITY AND AUTHENTICATION\n' >> "$AUDIT_RULES"
printf -- '-w /etc/passwd -p wa -k identity\n' >> "$AUDIT_RULES"
printf -- '-w /etc/shadow -p wa -k identity\n' >> "$AUDIT_RULES"
printf -- '-w /etc/group -p wa -k identity\n' >> "$AUDIT_RULES"
printf -- '-w /etc/gshadow -p wa -k identity\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Monitor sudoers changes\n' >> "$AUDIT_RULES"
printf -- '-w /etc/sudoers -p wa -k sudoers_change\n' >> "$AUDIT_RULES"
printf -- '-w /etc/sudoers.d/ -p wa -k sudoers_change\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Monitor SSH authorized keys\n' >> "$AUDIT_RULES"
printf -- '-w /root/.ssh/ -p wa -k ssh_keys\n' >> "$AUDIT_RULES"
printf -- '-w /home/ -p wa -k ssh_keys\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# Monitor SSH configuration\n' >> "$AUDIT_RULES"
printf -- '-w /etc/ssh/sshd_config -p wa -k sshd_config\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# PRIVILEGED COMMAND EXECUTION\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged_exec\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privileged_exec\n' >> "$AUDIT_RULES"
printf -- '-w /usr/bin/sudo -p x -k privileged_sudo\n' >> "$AUDIT_RULES"
printf -- '-w /bin/su -p x -k privileged_su\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# FILESYSTEM AND CONFIG CHANGES\n' >> "$AUDIT_RULES"
printf -- '-w /etc/ -p wa -k config_change\n' >> "$AUDIT_RULES"
printf -- '-w /var/www/ -p wa -k web_content_change\n' >> "$AUDIT_RULES"
printf -- '-w /etc/hosts -p wa -k network_config\n' >> "$AUDIT_RULES"
printf -- '-w /etc/resolv.conf -p wa -k network_config\n' >> "$AUDIT_RULES"
printf -- '-w /etc/cron.d/ -p wa -k cron_change\n' >> "$AUDIT_RULES"
printf -- '-w /etc/crontab -p wa -k cron_change\n' >> "$AUDIT_RULES"
printf -- '-w /var/spool/cron/ -p wa -k cron_change\n' >> "$AUDIT_RULES"
printf -- '-w /etc/systemd/system/ -p wa -k systemd_change\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# DANGEROUS COMMANDS\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b64 -S unlinkat -S rename -S renameat -k delete\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b32 -S unlinkat -S rename -S renameat -k delete\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -k permissions_change\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -k permissions_change\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b64 -S chown -S fchown -S lchown -k ownership_change\n' >> "$AUDIT_RULES"
printf -- '-a always,exit -F arch=b32 -S chown -S fchown -S lchown -k ownership_change\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# MODULE LOADING\n' >> "$AUDIT_RULES"
printf -- '-w /sbin/insmod -p x -k module_load\n' >> "$AUDIT_RULES"
printf -- '-w /sbin/rmmod -p x -k module_load\n' >> "$AUDIT_RULES"
printf -- '-w /sbin/modprobe -p x -k module_load\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# DATABASE ACCESS\n' >> "$AUDIT_RULES"
printf -- '-w /etc/postgresql/ -p wa -k db_config\n' >> "$AUDIT_RULES"
printf -- '-w /var/lib/postgresql/ -p rwa -k db_access\n' >> "$AUDIT_RULES"
printf '\n' >> "$AUDIT_RULES"
printf '# MAKE RULES IMMUTABLE UNTIL REBOOT - must be last line\n' >> "$AUDIT_RULES"
printf -- '-e 2\n' >> "$AUDIT_RULES"

echo "Audit rules written to $AUDIT_RULES" | tee -a "$LOG"

# 4. AUDITD MAIN CONFIGURATION
echo "Configuring auditd main settings..." | tee -a "$LOG"
AUDITD_CONF="/etc/audit/auditd.conf"

auditd_set() {
    local key="$1" val="$2"
    if grep -qE "^${key}" "$AUDITD_CONF"; then
        sed -i "s|^${key}.*|${key} = ${val}|" "$AUDITD_CONF"
    else
        echo "${key} = ${val}" >> "$AUDITD_CONF"
    fi
}

auditd_set "log_file" "/var/log/audit/audit.log"
auditd_set "log_format" "ENRICHED"
auditd_set "max_log_file" "100"
auditd_set "max_log_file_action" "ROTATE"
auditd_set "num_logs" "10"
auditd_set "space_left" "500"
auditd_set "space_left_action" "SYSLOG"
auditd_set "admin_space_left" "100"
auditd_set "admin_space_left_action" "HALT"
auditd_set "disk_full_action" "HALT"
auditd_set "disk_error_action" "HALT"

echo "Auditd configuration updated" | tee -a "$LOG"

# 5. CONFIGURE AUDISP TO FORWARD TO SYSLOG
echo "Configuring audisp-syslog plugin..." | tee -a "$LOG"
AUDISP_SYSLOG="/etc/audit/plugins.d/syslog.conf"
if [ -f "$AUDISP_SYSLOG" ]; then
    sed -i 's/^active.*/active = yes/' "$AUDISP_SYSLOG"
else
    printf 'active = yes\n' > "$AUDISP_SYSLOG"
    printf 'direction = out\n' >> "$AUDISP_SYSLOG"
    printf 'path = builtin_syslog\n' >> "$AUDISP_SYSLOG"
    printf 'type = builtin\n' >> "$AUDISP_SYSLOG"
    printf 'args = LOG_INFO\n' >> "$AUDISP_SYSLOG"
    printf 'format = string\n' >> "$AUDISP_SYSLOG"
fi
echo "Audisp-syslog plugin enabled" | tee -a "$LOG"

# 6. START AND ENABLE AUDITD
echo "Starting and enabling auditd..." | tee -a "$LOG"
systemctl enable auditd
systemctl restart auditd
echo "Auditd started and enabled" | tee -a "$LOG"

# 7. LOAD AUDIT RULES
echo "Loading audit rules..." | tee -a "$LOG"
augenrules --load 2>/dev/null || auditctl -R "$AUDIT_RULES"
echo "Audit rules loaded" | tee -a "$LOG"

# 8. VERIFY IMMUTABILITY FLAG
echo "Verifying audit rules are immutable..." | tee -a "$LOG"
if auditctl -l 2>/dev/null | grep -q "^-e 2"; then
    echo "VERIFIED: Audit rules are IMMUTABLE (require reboot to change)" | tee -a "$LOG"
else
    echo "Warning: Could not confirm immutability flag (-e 2). Check auditctl -l output." | tee -a "$LOG"
fi

# 9. CONFIGURE LOG ROTATION
echo "Configuring log rotation..." | tee -a "$LOG"
printf '/var/log/audit/audit.log {\n' > /etc/logrotate.d/nexus-audit
printf '    weekly\n' >> /etc/logrotate.d/nexus-audit
printf '    rotate 52\n' >> /etc/logrotate.d/nexus-audit
printf '    compress\n' >> /etc/logrotate.d/nexus-audit
printf '    delaycompress\n' >> /etc/logrotate.d/nexus-audit
printf '    missingok\n' >> /etc/logrotate.d/nexus-audit
printf '    notifempty\n' >> /etc/logrotate.d/nexus-audit
printf '    postrotate\n' >> /etc/logrotate.d/nexus-audit
printf '        /sbin/service auditd condrestart 2>/dev/null || true\n' >> /etc/logrotate.d/nexus-audit
printf '    endscript\n' >> /etc/logrotate.d/nexus-audit
printf '}\n' >> /etc/logrotate.d/nexus-audit
echo "Log rotation configured (52 weeks retention)" | tee -a "$LOG"

# 10. VERIFICATION SUMMARY
echo "=== LOGGING SETUP SUMMARY ===" | tee -a "$LOG"
echo "Rsyslog: forwarding to $CENTRAL_LOG_SERVER:$CENTRAL_LOG_PORT" | tee -a "$LOG"
echo "Auditd: monitoring sensitive files and privileged commands" | tee -a "$LOG"
echo "Audit rules: IMMUTABLE until reboot (-e 2)" | tee -a "$LOG"
echo "Audisp: forwarding audit events to syslog then to central server" | tee -a "$LOG"
auditctl -l 2>/dev/null | tee -a "$LOG" || echo "(auditctl -l: run as root to verify)" | tee -a "$LOG"
echo "==============================" | tee -a "$LOG"

echo "Logging setup complete" | tee -a "$LOG"
