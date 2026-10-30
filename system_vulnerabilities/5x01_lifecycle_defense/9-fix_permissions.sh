#!/bin/bash
# Fix permission issues identified in the audit

echo "=== Permission Remediation ==="
echo ""

echo "SUID/SGID issues:"
if [ -f /usr/local/bin/backup ]; then
    CURRENT_PERMS=$(stat -c '%a' /usr/local/bin/backup 2>/dev/null)
    chmod u-s /usr/local/bin/backup
    chmod 0755 /usr/local/bin/backup
    echo "  /usr/local/bin/backup: SUID removed (was $CURRENT_PERMS, now 0755)"
else
    echo "  /usr/local/bin/backup: Not found (already clean)"
fi
echo ""

echo "World-writable files:"
for wfile in /etc/cron.daily/backup.sh /opt/scripts/cleanup.sh; do
    if [ -f "$wfile" ]; then
        CURRENT_PERMS=$(stat -c '%a' "$wfile" 2>/dev/null)
        chmod 0755 "$wfile"
        echo "  $wfile: $CURRENT_PERMS → 0755"
    else
        echo "  $wfile: Not found"
    fi
done
echo ""

echo "Sensitive file permissions:"
if [ -f /var/www/html/config.php ]; then
    CURRENT_PERMS=$(stat -c '%a' /var/www/html/config.php 2>/dev/null)
    chmod 0640 /var/www/html/config.php
    chown www-data:www-data /var/www/html/config.php 2>/dev/null
    echo "  /var/www/html/config.php: $CURRENT_PERMS → 0640 (owner www-data)"
fi

if [ -f /home/devops/.ssh/id_rsa ]; then
    CURRENT_PERMS=$(stat -c '%a' /home/devops/.ssh/id_rsa 2>/dev/null)
    chmod 0600 /home/devops/.ssh/id_rsa
    echo "  /home/devops/.ssh/id_rsa: $CURRENT_PERMS → 0600"
fi
echo ""

echo "Credential exposure:"
if [ -f /var/www/html/.env ]; then
    mkdir -p /etc/novatech
    mv /var/www/html/.env /etc/novatech/app.env
    chmod 0640 /etc/novatech/app.env
    ln -sf /etc/novatech/app.env /var/www/html/.env
    echo "  /var/www/html/.env: Moved to /etc/novatech/app.env"
    echo "  Symlink created for application compatibility"
else
    echo "  /var/www/html/.env: Not found or already moved"
fi
echo ""

echo "All permission issues remediated."
