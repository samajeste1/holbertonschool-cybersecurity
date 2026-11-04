#!/bin/bash
# NovaTech Hardened Shield - identity controls (project 5x03)
# Idempotent. Exit 0 on success, 1 on a fatal error.

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: init-identity.sh must run as root"
    exit 1
fi

log() {
    echo "[identity] $1"
}

set_kv() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ -f "$file" ] && [ ! -w "$file" ]; then
        log "skip write, not writable: $file"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -q "^${key}[[:space:]]*=" "$file" 2>/dev/null; then
        sed -i "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    elif grep -q "^${key}[[:space:]]" "$file" 2>/dev/null; then
        sed -i "s|^${key}[[:space:]].*|${key} ${value}|" "$file"
    else
        echo "${key} = ${value}" >> "$file"
    fi
}

set_defs() {
    local key="$1"
    local value="$2"
    local file="/etc/login.defs"
    if [ ! -w "$file" ]; then
        return 0
    fi
    if grep -q "^${key}" "$file" 2>/dev/null; then
        sed -i "s|^${key}.*|${key} ${value}|" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

log "password policy (PAM pwquality)"
set_kv /etc/security/pwquality.conf minlen 12
set_kv /etc/security/pwquality.conf dcredit -1
set_kv /etc/security/pwquality.conf ucredit -1
set_kv /etc/security/pwquality.conf lcredit -1
set_kv /etc/security/pwquality.conf ocredit -1
set_kv /etc/security/pwquality.conf reject_username 1
if [ -w /etc/pam.d/common-password ] && ! grep -q pam_pwquality /etc/pam.d/common-password 2>/dev/null; then
    echo "password requisite pam_pwquality.so retry=3" >> /etc/pam.d/common-password
fi
if [ -w /etc/pam.d/common-password ] && ! grep -q pam_pwhistory /etc/pam.d/common-password 2>/dev/null; then
    echo "password required pam_pwhistory.so remember=5 use_authtok" >> /etc/pam.d/common-password
fi

log "password aging"
set_defs PASS_MAX_DAYS 90
set_defs PASS_MIN_DAYS 1
set_defs PASS_WARN_AGE 14
if id appuser >/dev/null 2>&1; then
    chage -M 90 -m 1 -W 14 appuser >/dev/null 2>&1 || true
fi

log "account lockout (faillock)"
set_kv /etc/security/faillock.conf deny 5
set_kv /etc/security/faillock.conf unlock_time 900
set_kv /etc/security/faillock.conf fail_interval 900
if test -w /etc/pam.d/common-auth && ! grep -q pam_faillock /etc/pam.d/common-auth 2>/dev/null; then
    sed -i '1i auth required pam_faillock.so preauth silent deny=5 unlock_time=900 fail_interval=900' /etc/pam.d/common-auth
    echo "auth required pam_faillock.so authfail deny=5 unlock_time=900 fail_interval=900" >> /etc/pam.d/common-auth
fi
if test -w /etc/pam.d/common-account && ! grep -q pam_faillock /etc/pam.d/common-account 2>/dev/null; then
    echo "account required pam_faillock.so" >> /etc/pam.d/common-account
fi

log "fail2ban sshd jail"
mkdir -p /etc/fail2ban 2>/dev/null || true
if [ -w /etc/fail2ban ] || [ ! -e /etc/fail2ban/jail.local ]; then
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOF
fi

log "SSH hardening"
SSHD_DROP="/etc/ssh/sshd_config.d/99-hardened.conf"
mkdir -p /etc/ssh/sshd_config.d 2>/dev/null || true
if [ -w /etc/ssh/sshd_config.d ] || [ ! -e "$SSHD_DROP" ]; then
    cat > "$SSHD_DROP" << 'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
Banner /etc/issue.net
EOF
fi
if [ -w /etc/ssh/sshd_config ]; then
    if grep -q '^PermitRootLogin' /etc/ssh/sshd_config; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi
    if grep -q '^PasswordAuthentication' /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi
    if grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi
    if grep -q '^Banner' /etc/ssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
fi

log "root account lockdown"
root_state="$(passwd -S root 2>/dev/null | awk '{print $2}')"
if [ "$root_state" != "L" ] && [ "$root_state" != "LK" ]; then
    passwd -l root >/dev/null 2>&1 || true
    log "root account locked"
else
    log "root account already locked"
fi

if id appuser >/dev/null 2>&1; then
    install -d -m 700 -o appuser -g appuser /home/appuser/.ssh
    chmod 700 /home/appuser
    if [ ! -s /home/appuser/.ssh/authorized_keys ]; then
        if [ ! -f /home/appuser/.ssh/id_ed25519 ]; then
            ssh-keygen -t ed25519 -f /home/appuser/.ssh/id_ed25519 -N "" -C "appuser@novatech" >/dev/null 2>&1 || true
        fi
        if [ -f /home/appuser/.ssh/id_ed25519.pub ]; then
            cat /home/appuser/.ssh/id_ed25519.pub > /home/appuser/.ssh/authorized_keys
        fi
    fi
    chown -R appuser:appuser /home/appuser/.ssh 2>/dev/null || true
    chmod 700 /home/appuser/.ssh 2>/dev/null || true
    chmod 600 /home/appuser/.ssh/authorized_keys /home/appuser/.ssh/id_ed25519 2>/dev/null || true
    log "appuser SSH directory prepared (key generated at runtime, not baked in)"
fi

log "identity complete"
exit 0
