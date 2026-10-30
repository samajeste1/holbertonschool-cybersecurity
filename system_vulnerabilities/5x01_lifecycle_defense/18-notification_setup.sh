#!/bin/bash
# Configure comprehensive logging and email notifications

echo "=== Notification Configuration ==="
echo ""

CONFIG="/etc/apt/apt.conf.d/50unattended-upgrades"

# Ensure config file exists
if [ ! -f "$CONFIG" ]; then
    touch "$CONFIG"
fi

# Remove existing notification settings
sed -i '/Unattended-Upgrade::Mail /d' "$CONFIG"
sed -i '/Unattended-Upgrade::MailOnlyOnError/d' "$CONFIG"
sed -i '/Unattended-Upgrade::MailReport/d' "$CONFIG"
sed -i '/Unattended-Upgrade::SyslogEnable/d' "$CONFIG"
sed -i '/Unattended-Upgrade::SyslogFacility/d' "$CONFIG"

# Add notification settings
cat >> "$CONFIG" << 'EOF'

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF

echo "Email settings:"
echo '  Mail::OnlyOnError: "false"'
echo '  Mail::Report: "on-change"'
echo "  Recipient: root (local delivery)"
echo ""

echo "Logging settings:"
echo '  Syslog::Enable: "true"'
echo '  Syslog::Facility: "daemon"'
echo ""

echo "Log locations:"
echo "  /var/log/unattended-upgrades/unattended-upgrades.log"
echo "  /var/log/unattended-upgrades/unattended-upgrades-dpkg.log"

# Ensure log directory exists
mkdir -p /var/log/unattended-upgrades
echo ""

echo "Notification system configured."
echo "All update activity will be logged and reported."
