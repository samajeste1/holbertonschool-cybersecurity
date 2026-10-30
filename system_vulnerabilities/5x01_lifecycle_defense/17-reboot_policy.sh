#!/bin/bash
# Configure automatic reboot policy for kernel updates

echo "=== Automatic Reboot Policy ==="
echo ""

CONFIG="/etc/apt/apt.conf.d/50unattended-upgrades"

# Ensure config file exists
if [ ! -f "$CONFIG" ]; then
    touch "$CONFIG"
fi

# Remove existing reboot settings
sed -i '/Unattended-Upgrade::Automatic-Reboot /d' "$CONFIG"
sed -i '/Unattended-Upgrade::Automatic-Reboot-Time/d' "$CONFIG"
sed -i '/Unattended-Upgrade::Automatic-Reboot-WithUsers/d' "$CONFIG"

# Add reboot settings
cat >> "$CONFIG" << 'EOF'

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
EOF

echo "Configuring $CONFIG..."
echo ""

echo "Reboot settings:"
echo '  Automatic-Reboot: "true"'
echo '  Automatic-Reboot-Time: "04:00"'
echo '  Automatic-Reboot-WithUsers: "false"'
echo ""

echo "Additional safeguards:"
echo "  Reboot only when required (kernel/libc updates)"
echo "  Skip reboot if users are logged in"
echo ""

echo "Reboot policy configured."
echo "System will auto-reboot at 04:00 when required."
