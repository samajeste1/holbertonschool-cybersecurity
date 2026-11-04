#!/bin/bash
# Start-time supervisor. No manual steps after the container starts.

/opt/novatech/scripts/init-hardening.sh || exit 1
/opt/novatech/scripts/init-identity.sh || exit 1
/opt/novatech/scripts/init-services.sh || exit 1

if test "$#" -gt 0; then
    exec "$@"
fi

while true; do
    if ! pgrep -x nginx >/dev/null 2>&1; then
        nginx || true
    fi
    if ! pgrep -x sshd >/dev/null 2>&1; then
        /usr/sbin/sshd || true
    fi
    sleep 30
done
