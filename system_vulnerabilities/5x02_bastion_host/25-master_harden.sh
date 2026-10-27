#!/bin/bash
# Master hardening script for Ubuntu 20.04 bastion host
# Idempotent - safe to run multiple times
# Run as root: sudo bash 25-master_harden.sh

set -euo pipefail

LOGFILE="/var/log/hardening_$(date +%Y%m%d_%H%M%S).log"
SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "=== Master Hardening Script ==="
log "Target: Ubuntu 20.04 Bastion Host"
log "Log file: $LOGFILE"
log ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root (sudo bash $0)"
    exit 1
fi

# ============================================================
# MODULE 1: Kernel Parameter Hardening
# ============================================================
log "--- Module 1: Kernel Parameter Hardening ---"

apply_sysctl() {
    local param="$1"
    local value="$2"
    local desc="$3"

    CURRENT=$(sysctl -n "$param" 2>/dev/null || echo "N/A")
    if [ "$CURRENT" = "$value" ]; then
        log "  $param = $value (already set)"
    else
        sysctl -w "$param=$value" > /dev/null 2>&1
        log "  $param: $CURRENT -> $value ($desc)"
    fi

    # Persist to config file (idempotent)
    if grep -q "^$param" "$SYSCTL_CONF" 2>/dev/null; then
        sed -i "s|^$param.*|$param = $value|" "$SYSCTL_CONF"
    else
        echo "$param = $value" >> "$SYSCTL_CONF"
    fi
}

# Create sysctl config if it doesn't exist
touch "$SYSCTL_CONF"

# Disable IP forwarding
apply_sysctl "net.ipv4.ip_forward" "0" "Disable IPv4 forwarding"
apply_sysctl "net.ipv6.conf.all.forwarding" "0" "Disable IPv6 forwarding"

# Block ICMP redirects
apply_sysctl "net.ipv4.conf.all.accept_redirects" "0" "Block ICMP redirect accept"
apply_sysctl "net.ipv4.conf.default.accept_redirects" "0" "Block ICMP redirect accept"
apply_sysctl "net.ipv4.conf.all.send_redirects" "0" "Block ICMP redirect send"
apply_sysctl "net.ipv4.conf.default.send_redirects" "0" "Block ICMP redirect send"
apply_sysctl "net.ipv6.conf.all.accept_redirects" "0" "Block IPv6 redirects"
apply_sysctl "net.ipv6.conf.default.accept_redirects" "0" "Block IPv6 redirects"

# Reverse path filtering
apply_sysctl "net.ipv4.conf.all.rp_filter" "1" "Enable strict RP filter"
apply_sysctl "net.ipv4.conf.default.rp_filter" "1" "Enable strict RP filter"

# SYN cookies
apply_sysctl "net.ipv4.tcp_syncookies" "1" "Enable SYN cookies"

# ICMP hardening
apply_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" "1" "Ignore broadcast pings"
apply_sysctl "net.ipv4.icmp_ignore_bogus_error_responses" "1" "Ignore bogus ICMP errors"

# Source routing
apply_sysctl "net.ipv4.conf.all.accept_source_route" "0" "Block source routing"
apply_sysctl "net.ipv4.conf.default.accept_source_route" "0" "Block source routing"
apply_sysctl "net.ipv6.conf.all.accept_source_route" "0" "Block IPv6 source routing"

sysctl -p "$SYSCTL_CONF" > /dev/null 2>&1
log "  Kernel parameters persisted to $SYSCTL_CONF"
log ""

# ============================================================
# MODULE 2: Package Minimization
# ============================================================
log "--- Module 2: Package Minimization ---"

# Remove compilers if present
for pkg in gcc g++ make build-essential; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        apt-get remove -y "$pkg" > /dev/null 2>&1
        log "  Removed: $pkg"
    else
        log "  $pkg: not installed (skip)"
    fi
done

# Restrict network tools to root only
for tool in /usr/bin/nmap /usr/sbin/tcpdump /usr/bin/ncat /usr/bin/netcat /usr/bin/nc; do
    if [ -f "$tool" ]; then
        CURRENT_PERMS=$(stat -c '%a' "$tool")
        if [ "$CURRENT_PERMS" != "750" ]; then
            chmod 0750 "$tool"
            log "  $tool: restricted to root (0750)"
        else
            log "  $tool: already restricted (0750)"
        fi
    fi
done
log ""

# ============================================================
# MODULE 3: SUID Reduction
# ============================================================
log "--- Module 3: SUID Reduction ---"

PRESERVE="/usr/bin/sudo /usr/bin/passwd /usr/bin/su /usr/bin/ping /usr/lib/openssh/ssh-keysign"

find / -perm -4000 -type f 2>/dev/null | while read -r bin; do
    SKIP=0
    for safe in $PRESERVE; do
        if [ "$bin" = "$safe" ]; then
            SKIP=1
            break
        fi
    done
    if [ "$SKIP" -eq 0 ]; then
        chmod u-s "$bin" 2>/dev/null && log "  $bin: SUID removed"
    fi
done
log ""

# ============================================================
# MODULE 4: Filesystem Hardening
# ============================================================
log "--- Module 4: Filesystem Hardening ---"

# Harden /tmp
if ! grep -q 'tmpfs /tmp tmpfs' /etc/fstab 2>/dev/null; then
    # Remove existing /tmp entries
    sed -i '/\/tmp/d' /etc/fstab 2>/dev/null
    echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
    log "  /tmp: added noexec,nosuid,nodev to fstab"
else
    log "  /tmp: already hardened in fstab"
fi

# Harden /var/tmp (bind to /tmp)
if ! grep -q '/tmp /var/tmp none bind' /etc/fstab 2>/dev/null; then
    sed -i '/\/var\/tmp/d' /etc/fstab 2>/dev/null
    echo "/tmp /var/tmp none bind 0 0" >> /etc/fstab
    log "  /var/tmp: bind mount to /tmp configured"
else
    log "  /var/tmp: already hardened in fstab"
fi

# Harden /dev/shm
if ! grep -q 'tmpfs /dev/shm tmpfs.*noexec' /etc/fstab 2>/dev/null; then
    sed -i '/\/dev\/shm/d' /etc/fstab 2>/dev/null
    echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
    log "  /dev/shm: added noexec,nosuid,nodev to fstab"
else
    log "  /dev/shm: already hardened in fstab"
fi

# Remount
mount -o remount /tmp 2>/dev/null || true
mount -o bind /tmp /var/tmp 2>/dev/null || true
mount -o remount /dev/shm 2>/dev/null || true
log ""

# ============================================================
# MODULE 5: Service Minimization
# ============================================================
log "--- Module 5: Service Minimization ---"

for svc in cups cups-browsed avahi-daemon bluetooth snapd postfix rpcbind nfs-server \
           ModemManager accounts-daemon whoopsie kerneloops apport; do
    if systemctl is-enabled "$svc" 2>/dev/null | grep -q 'enabled'; then
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
        log "  $svc: disabled and stopped"
    else
        log "  $svc: already disabled (skip)"
    fi
done
log ""

# ============================================================
# MODULE 6: Root Account Lockdown
# ============================================================
log "--- Module 6: Root Account Lockdown ---"

# Lock root account
ROOT_STATUS=$(passwd -S root 2>/dev/null | awk '{print $2}')
if [ "$ROOT_STATUS" != "L" ] && [ "$ROOT_STATUS" != "LK" ]; then
    passwd -l root 2>/dev/null
    log "  Root account: LOCKED"
else
    log "  Root account: already locked"
fi

# Disable SSH root login
if grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null; then
    log "  SSH root login: already disabled"
else
    if grep -q '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    elif grep -q '^#PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi
    log "  SSH root login: disabled (PermitRootLogin no)"
fi
log ""

# ============================================================
# MODULE 7: Legal Banner
# ============================================================
log "--- Module 7: Legal Banner ---"

BANNER_FILE="/etc/issue.net"
BANNER_TEXT="=====================================
AUTHORIZED ACCESS ONLY

This system is the property of NovaTech Solutions.
Unauthorized access is prohibited and will be prosecuted.
All activities are monitored and logged.
====================================="

if [ -f "$BANNER_FILE" ] && grep -q "AUTHORIZED ACCESS ONLY" "$BANNER_FILE" 2>/dev/null; then
    log "  Banner: already configured"
else
    echo "$BANNER_TEXT" > "$BANNER_FILE"
    log "  Banner: written to $BANNER_FILE"
fi

# Enable in SSH config
if grep -q '^Banner /etc/issue.net' /etc/ssh/sshd_config 2>/dev/null; then
    log "  SSH Banner: already enabled"
else
    if grep -q '^Banner' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
    elif grep -q '^#Banner' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's|^#Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    log "  SSH Banner: enabled"
fi

# Reload SSH
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
log ""

# ============================================================
# SUMMARY
# ============================================================
log "=== Hardening Complete ==="
log ""
log "Modules applied:"
log "  1. Kernel parameters (15 sysctl settings)"
log "  2. Package minimization (compilers removed, tools restricted)"
log "  3. SUID reduction (non-essential SUID bits removed)"
log "  4. Filesystem hardening (noexec on /tmp, /var/tmp, /dev/shm)"
log "  5. Service minimization (13 unnecessary services disabled)"
log "  6. Root account locked (sudo enforced)"
log "  7. Legal banner configured"
log ""
log "Log saved to: $LOGFILE"
log "Run 'lynis audit system' to verify hardening score."
