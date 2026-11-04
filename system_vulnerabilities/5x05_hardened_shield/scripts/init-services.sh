#!/bin/bash
# NovaTech Hardened Shield - start and verify nginx and sshd
# Idempotent. Exit 0 when both services are healthy, 1 otherwise.

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: init-services.sh must run as root"
    exit 1
fi

log() {
    echo "[services] $1"
}

mkdir -p /run/sshd /var/run/sshd /var/log/nginx /var/cache/nginx /var/lib/nginx /var/log
ssh-keygen -A >/dev/null 2>&1 || true

if ! pgrep -x sshd >/dev/null 2>&1; then
    if ! /usr/sbin/sshd; then
        log "ERROR: sshd failed to start"
        exit 1
    fi
    log "sshd started"
else
    log "sshd already running"
fi

if ! pgrep -x nginx >/dev/null 2>&1; then
    if ! nginx; then
        log "ERROR: nginx failed to start"
        exit 1
    fi
    log "nginx started"
else
    log "nginx already running"
fi

if command -v fail2ban-server >/dev/null 2>&1 && ! pgrep -x fail2ban-server >/dev/null 2>&1; then
    fail2ban-server -b >/dev/null 2>&1 || log "fail2ban not started (non-fatal in this container)"
fi

ok=0
if pgrep -x sshd >/dev/null 2>&1; then
    log "verify sshd: running"
else
    log "verify sshd: NOT running"
    ok=1
fi

if pgrep -x nginx >/dev/null 2>&1; then
    log "verify nginx: running"
else
    log "verify nginx: NOT running"
    ok=1
fi

if command -v ss >/dev/null 2>&1; then
    ss -ltn | grep -q ':22' && log "port 22 listening" || log "port 22 not confirmed"
    ss -ltn | grep -q ':80' && log "port 80 listening" || log "port 80 not confirmed"
fi

if curl -fsS http://127.0.0.1/ >/dev/null 2>&1; then
    log "health check: web server responds on port 80"
else
    log "health check: web server did not respond"
    ok=1
fi

if [ "$ok" -ne 0 ]; then
    exit 1
fi

log "services healthy"
exit 0
