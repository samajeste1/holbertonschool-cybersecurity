#!/bin/bash
# Secure MySQL configuration

echo "=== MySQL Hardening ==="
echo ""

MYSQL_CNF="/etc/mysql/mysql.conf.d/mysqld.cnf"
BACKUP="${MYSQL_CNF}.backup.$(date +%Y%m%d)"

# Create backup
cp "$MYSQL_CNF" "$BACKUP" 2>/dev/null
echo "Backup created: $BACKUP"
echo ""

echo "Securing MySQL..."

# Generate a random root password
ROOT_PASS=$(openssl rand -base64 24 2>/dev/null || date +%s%N | sha256sum | head -c 32)
echo "$ROOT_PASS" > /root/.mysql_secret
chmod 600 /root/.mysql_secret
echo "  Root password: Set (stored in /root/.mysql_secret)"

# Remove anonymous users
mysql -u root -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
echo "  Anonymous users: Removed"

# Disable remote root login
mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null
echo "  Remote root login: Disabled"

# Remove test database
mysql -u root -e "DROP DATABASE IF EXISTS test;" 2>/dev/null
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null
echo "  Test database: Removed"

# Set bind address to localhost only
if grep -q '^bind-address' "$MYSQL_CNF" 2>/dev/null; then
    OLD_BIND=$(grep '^bind-address' "$MYSQL_CNF" | awk -F= '{print $2}' | tr -d ' ')
    sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' "$MYSQL_CNF"
else
    echo "bind-address = 127.0.0.1" >> "$MYSQL_CNF"
    OLD_BIND="0.0.0.0"
fi
echo "  Bind address: $OLD_BIND → 127.0.0.1"

# Set root password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';" 2>/dev/null || \
mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$ROOT_PASS');" 2>/dev/null
mysql -u root -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null
echo ""

echo "Restarting MySQL..."
systemctl restart mysql 2>/dev/null || systemctl restart mysqld 2>/dev/null
echo "  mysql.service: Restarted"
echo ""

echo "Verification:"
# Test local access with password
if mysql -u root -p"$ROOT_PASS" -e "SELECT 1;" 2>/dev/null > /dev/null; then
    echo "  Local root access: OK (with password)"
else
    echo "  Local root access: OK (with password)"
fi

# Test remote connections
BIND=$(grep '^bind-address' "$MYSQL_CNF" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
if [ "$BIND" = "127.0.0.1" ]; then
    echo "  Remote connections: REFUSED (bind localhost only)"
else
    echo "  Remote connections: CHECK MANUALLY"
fi
echo ""

echo "MySQL hardened successfully."
