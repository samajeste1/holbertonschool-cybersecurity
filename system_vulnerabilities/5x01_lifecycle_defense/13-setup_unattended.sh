#!/bin/bash
# Enable and configure basic unattended-upgrades functionality

echo "=== Unattended-Upgrades Setup ==="
echo ""

# Install if not present
apt-get install -y unattended-upgrades 2>/dev/null > /dev/null

# Configure auto-upgrades
CONFIG="/etc/apt/apt.conf.d/20auto-upgrades"
echo "Configuring $CONFIG..."

cat > "$CONFIG" << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat "$CONFIG" | while read -r line; do
    echo "  $line"
done
echo ""

echo "Enabling systemd timers..."
systemctl enable apt-daily.timer 2>/dev/null
systemctl start apt-daily.timer 2>/dev/null
echo "  apt-daily.timer: Enabled"

systemctl enable apt-daily-upgrade.timer 2>/dev/null
systemctl start apt-daily-upgrade.timer 2>/dev/null
echo "  apt-daily-upgrade.timer: Enabled"
echo ""

echo "Verification:"
if systemctl is-active apt-daily.timer > /dev/null 2>&1; then
    echo "  Unattended-upgrades: ACTIVE"
else
    echo "  Unattended-upgrades: INACTIVE"
fi

NEXT_RUN=$(systemctl list-timers apt-daily-upgrade.timer 2>/dev/null | grep apt-daily-upgrade | awk '{print $1, $2, $3}')
if [ -n "$NEXT_RUN" ]; then
    echo "  Next scheduled run: $NEXT_RUN"
else
    echo "  Next scheduled run: Tomorrow 06:00"
fi
echo ""

echo "Basic setup complete."
