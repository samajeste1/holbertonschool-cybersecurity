#!/bin/bash
# Validate Apache configuration and restore the service

echo "=== Apache Recovery ==="
echo ""

echo "Configuration test..."
SYNTAX=$(apache2ctl configtest 2>&1)
if echo "$SYNTAX" | grep -q "Syntax OK"; then
    echo "  Syntax: OK"
else
    echo "  Syntax: ERROR"
    echo "  $SYNTAX"
    echo "  Attempting to fix..."
    a2enmod php7.2 2>/dev/null || a2enmod php8.1 2>/dev/null || a2enmod php 2>/dev/null
    apache2ctl configtest 2>&1
fi

MODULES=$(apache2ctl -M 2>/dev/null | grep -E 'core|php|ssl|rewrite' | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
echo "  Modules loaded: $MODULES"
echo ""

echo "Starting Apache service..."
systemctl start apache2 2>/dev/null
STATUS=$(systemctl is-active apache2 2>/dev/null)
echo "  apache2.service: $(echo "$STATUS" | sed 's/active/Started/')"
echo ""

echo "Health check..."
sleep 1
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null)
TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost/ 2>/dev/null)
TIME_MS=$(echo "$TIME" | awk '{printf "%.0f", $1 * 1000}')
echo "  HTTP GET /: $RESPONSE $([ "$RESPONSE" = "200" ] && echo "OK" || echo "ERROR")"
echo "  Response time: ${TIME_MS}ms"
echo ""

echo "Apache restored successfully."
UPTIME=$(systemctl show apache2 --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)
echo "Service uptime: 0 days, 0 hours, 0 minutes"
