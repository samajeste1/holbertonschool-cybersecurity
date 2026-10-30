#!/bin/bash
# Add critical packages to the unattended-upgrades blacklist

echo "=== Package Blacklist Configuration ==="
echo ""

CONFIG="/etc/apt/apt.conf.d/50unattended-upgrades"

# Read existing config or create base
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'CONF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
CONF
fi

# Remove existing blacklist section if present
sed -i '/Unattended-Upgrade::Package-Blacklist/,/^};/d' "$CONFIG"

# Add blacklist
cat >> "$CONFIG" << 'CONF'

Unattended-Upgrade::Package-Blacklist {
    "apache2";
    "apache2-bin";
    "mysql-server";
    "mysql-server-*";
    "nginx";
    "docker-ce";
};
CONF

echo "Adding to Unattended-Upgrade::Package-Blacklist:"
echo '  + "apache2"'
echo '  + "apache2-bin"'
echo '  + "mysql-server"'
echo '  + "mysql-server-*"'
echo '  + "nginx"'
echo '  + "docker-ce"'
echo ""

echo "Blacklist written to $CONFIG"
echo ""
echo "These packages will NOT be automatically upgraded."
echo "Manual review required for security updates."
