#!/bin/bash
# NovaTech Hardened Shield - system hardening (project 5x02 controls)
# Idempotent. Exit 0 on success, 1 on a fatal error.

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: init-hardening.sh must run as root"
    exit 1
fi

log() {
    echo "[hardening] $1"
}

ensure_line() {
    local file="$1"
    local line="$2"
    if [ -f "$file" ] && grep -qxF "$line" "$file" 2>/dev/null; then
        return 0
    fi
    if [ -e "$file" ] && [ ! -w "$file" ]; then
        log "skip write, not writable: $file"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    echo "$line" >> "$file"
}

log "kernel parameters (sysctl)"
SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"
touch "$SYSCTL_CONF" 2>/dev/null || true
apply_sysctl() {
    local param="$1"
    local value="$2"
    if [ -w "$SYSCTL_CONF" ] || [ ! -e "$SYSCTL_CONF" ]; then
        if [ -f "$SYSCTL_CONF" ] && grep -q "^${param}[[:space:]]*=" "$SYSCTL_CONF" 2>/dev/null; then
            sed -i "s|^${param}[[:space:]]*=.*|${param} = ${value}|" "$SYSCTL_CONF"
        else
            echo "${param} = ${value}" >> "$SYSCTL_CONF"
        fi
    fi
    sysctl -w "${param}=${value}" >/dev/null 2>&1 || log "sysctl ${param} not writable in this namespace"
}

apply_sysctl net.ipv4.ip_forward 0
apply_sysctl net.ipv6.conf.all.forwarding 0
apply_sysctl net.ipv4.conf.all.accept_redirects 0
apply_sysctl net.ipv4.conf.default.accept_redirects 0
apply_sysctl net.ipv4.conf.all.send_redirects 0
apply_sysctl net.ipv4.conf.default.send_redirects 0
apply_sysctl net.ipv6.conf.all.accept_redirects 0
apply_sysctl net.ipv4.conf.all.rp_filter 1
apply_sysctl net.ipv4.conf.default.rp_filter 1
apply_sysctl net.ipv4.tcp_syncookies 1
apply_sysctl net.ipv4.icmp_echo_ignore_broadcasts 1
apply_sysctl net.ipv4.icmp_ignore_bogus_error_responses 1
apply_sysctl net.ipv4.conf.all.accept_source_route 0
apply_sysctl net.ipv4.conf.default.accept_source_route 0
apply_sysctl net.ipv6.conf.all.accept_source_route 0
apply_sysctl kernel.randomize_va_space 2
apply_sysctl kernel.dmesg_restrict 1
apply_sysctl fs.suid_dumpable 0
sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true

log "filesystem security"
ensure_line /etc/fstab "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0"
ensure_line /etc/fstab "/tmp /var/tmp none bind 0 0"
ensure_line /etc/fstab "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0"
mount -o remount,noexec,nosuid,nodev /tmp >/dev/null 2>&1 || true
mount -o remount,noexec,nosuid,nodev /dev/shm >/dev/null 2>&1 || true
chmod 600 /etc/shadow 2>/dev/null || true
chmod 644 /etc/passwd /etc/group 2>/dev/null || true

log "service minimization"
if command -v systemctl >/dev/null 2>&1; then
    for svc in cups cups-browsed avahi-daemon bluetooth snapd postfix rpcbind nfs-server ModemManager accounts-daemon whoopsie apport; do
        if systemctl is-enabled "$svc" 2>/dev/null | grep -q enabled; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || true
            log "disabled $svc"
        fi
    done
else
    log "systemd not available, service minimization recorded as not applicable"
fi

log "SUID audit"
while IFS= read -r bin; do
    kept=0
    for safe in /usr/bin/sudo /usr/bin/passwd /usr/bin/su /usr/lib/openssh/ssh-keysign /usr/sbin/unix_chkpwd; do
        if test "$bin" = "$safe"; then
            kept=1
        fi
    done
    if test "$kept" -eq 0; then
        chmod u-s "$bin" 2>/dev/null && log "SUID removed: $bin"
    else
        log "SUID kept: $bin"
    fi
done < <(find /usr /bin /sbin -perm -4000 -type f 2>/dev/null)

log "package minimization"
for pkg in gcc g++ make build-essential; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get remove -y "$pkg" >/dev/null 2>&1 || true
        log "removed $pkg"
    fi
done

log "legal banner"
if [ -w /etc/issue.net ] || [ ! -e /etc/issue.net ]; then
    cat > /etc/issue.net << 'EOF'
AUTHORIZED ACCESS ONLY
This system is the property of NovaTech Solutions.
Unauthorized access is prohibited and will be prosecuted.
All activities are monitored and logged.
EOF
    cp /etc/issue.net /etc/issue 2>/dev/null || true
fi

log "hardening complete"
exit 0
