#!/bin/bash
# RBAC Setup Script - Nexus Financial
# Creates groups, users, sudoers, SSH keys, file permissions
# Idempotent: safe to run multiple times

set -euo pipefail

LOG="/var/log/nexus_rbac.log"
echo "Starting RBAC setup" | tee -a "$LOG"

# Create groups if they do not exist
if ! getent group sysadmin > /dev/null 2>&1; then
    groupadd sysadmin
    echo "Created group sysadmin" | tee -a "$LOG"
fi

if ! getent group devs > /dev/null 2>&1; then
    groupadd devs
    echo "Created group devs" | tee -a "$LOG"
fi

if ! getent group ops > /dev/null 2>&1; then
    groupadd ops
    echo "Created group ops" | tee -a "$LOG"
fi

if ! getent group auditors > /dev/null 2>&1; then
    groupadd auditors
    echo "Created group auditors" | tee -a "$LOG"
fi

# Create user nexus_admin (sysadmin role)
if ! id nexus_admin > /dev/null 2>&1; then
    useradd -m -s /bin/bash -g sysadmin -c "Nexus CISO Account" nexus_admin
    mkdir -p /home/nexus_admin/.ssh
    chmod 700 /home/nexus_admin/.ssh
    echo "Created user nexus_admin" | tee -a "$LOG"
fi

# Create user sarah (devs role - Lead Developer)
if ! id sarah > /dev/null 2>&1; then
    useradd -m -s /bin/bash -g devs -c "Lead Developer" sarah
    mkdir -p /home/sarah/.ssh
    chmod 700 /home/sarah/.ssh
    echo "Created user sarah" | tee -a "$LOG"
fi

# Create user dave (ops role - CTO read-only)
if ! id dave > /dev/null 2>&1; then
    useradd -m -s /bin/bash -g ops -c "CTO Operations Read-Only" dave
    mkdir -p /home/dave/.ssh
    chmod 700 /home/dave/.ssh
    echo "Created user dave" | tee -a "$LOG"
fi

# Create user auditor (auditors role)
if ! id auditor > /dev/null 2>&1; then
    useradd -m -s /bin/bash -g auditors -c "External Auditor Read-Only" auditor
    mkdir -p /home/auditor/.ssh
    chmod 700 /home/auditor/.ssh
    echo "Created user auditor" | tee -a "$LOG"
fi

# Generate individual SSH keys (replaces shared nexus_master.pem)
for user in nexus_admin sarah dave; do
    keyfile="/home/${user}/.ssh/id_ed25519"
    if [ ! -f "$keyfile" ]; then
        sudo -u "$user" ssh-keygen -t ed25519 -f "$keyfile" -N "" -C "${user}@nexus-financial" 2>/dev/null
        cat "${keyfile}.pub" >> "/home/${user}/.ssh/authorized_keys"
        chmod 600 "/home/${user}/.ssh/authorized_keys"
        chown -R "${user}" "/home/${user}/.ssh"
        echo "Generated ed25519 key for ${user}" | tee -a "$LOG"
    fi
done

# Revoke shared nexus_master.pem from all authorized_keys
for authkeys in /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys; do
    if [ -f "$authkeys" ]; then
        sed -i '/nexus_master/d' "$authkeys"
    fi
done
echo "Revoked nexus_master.pem from all authorized_keys" | tee -a "$LOG"

# Disable password login for all managed accounts
for user in nexus_admin sarah dave auditor; do
    passwd -l "$user" > /dev/null 2>&1 || true
done

# Strict home directory permissions (700)
chmod 700 /home/nexus_admin
chmod 700 /home/sarah
chmod 700 /home/dave
chmod 700 /home/auditor
echo "Home directories set to 700" | tee -a "$LOG"

# Sudoers configuration - least privilege
SUDOERS_FILE="/etc/sudoers.d/nexus_rbac"
cat > /tmp/nexus_rbac_sudoers << 'SUDOERS'
# Nexus Financial RBAC Sudoers Policy

# sysadmin - full sudo with password
%sysadmin ALL=(ALL:ALL) ALL

# devs - restart nginx and app services only (no password)
%devs ALL=(root) NOPASSWD: /bin/systemctl restart nginx
%devs ALL=(root) NOPASSWD: /bin/systemctl restart app
%devs ALL=(root) NOPASSWD: /bin/systemctl status nginx
%devs ALL=(root) NOPASSWD: /bin/systemctl status app
%devs ALL=(root) NOPASSWD: /usr/bin/journalctl -u nginx
%devs ALL=(root) NOPASSWD: /usr/bin/journalctl -u app

# ops (dave) - read logs only, no service management
%ops ALL=(root) NOPASSWD: /usr/bin/journalctl
%ops ALL=(root) NOPASSWD: /bin/systemctl status *

# auditors - read audit logs only
%auditors ALL=(root) NOPASSWD: /usr/bin/aureport
%auditors ALL=(root) NOPASSWD: /usr/bin/ausearch

# Deny root shell to all non-sysadmin roles
%devs ALL=(root) !/bin/bash, !/bin/sh
%ops ALL=(root) !/bin/bash, !/bin/sh
%auditors ALL=(root) !/bin/bash, !/bin/sh
SUDOERS

if visudo -c -f /tmp/nexus_rbac_sudoers; then
    cp /tmp/nexus_rbac_sudoers "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "Sudoers policy installed" | tee -a "$LOG"
fi
rm -f /tmp/nexus_rbac_sudoers

# Lock root account (sudo still works for sysadmin)
passwd -l root > /dev/null 2>&1 || true
echo "Root password login disabled" | tee -a "$LOG"

echo "RBAC setup complete" | tee -a "$LOG"
