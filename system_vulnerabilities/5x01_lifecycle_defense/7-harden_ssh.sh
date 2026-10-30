#!/bin/bash
# Harden SSH configuration with backup

echo "=== SSH Hardening ==="
echo ""

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSHD_CONFIG}.backup.$(date +%Y%m%d)"

# Create backup
cp "$SSHD_CONFIG" "$BACKUP"
echo "Backup created: $BACKUP"
echo ""

echo "Applying hardening measures..."

# Function to set SSH config parameter
set_ssh_param() {
    local param="$1"
    local value="$2"
    local old_value

    old_value=$(grep "^${param}" "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ -z "$old_value" ]; then
        old_value=$(grep "^#${param}" "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    fi
    [ -z "$old_value" ] && old_value="default"

    # Remove existing lines (both commented and uncommented)
    sed -i "/^#*${param}/d" "$SSHD_CONFIG"
    # Add new setting
    echo "${param} ${value}" >> "$SSHD_CONFIG"

    echo "  ${param}: ${old_value} → ${value}"
}

set_ssh_param "PermitRootLogin" "no"
set_ssh_param "PasswordAuthentication" "no"
set_ssh_param "X11Forwarding" "no"
set_ssh_param "MaxAuthTries" "3"
set_ssh_param "ClientAliveInterval" "300"
set_ssh_param "ClientAliveCountMax" "2"
echo ""

# Test configuration
echo -n "Configuration test: "
if sshd -t 2>/dev/null; then
    echo "OK"
else
    echo "FAILED - restoring backup"
    cp "$BACKUP" "$SSHD_CONFIG"
    exit 1
fi
echo ""

echo "Reloading SSH service..."
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
echo "  sshd.service: Reloaded"
echo ""

echo "SSH hardened successfully."
echo ""
echo "WARNING: Ensure key-based authentication is configured"
echo "         before closing this session."
