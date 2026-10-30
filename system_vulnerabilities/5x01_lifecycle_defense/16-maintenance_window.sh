#!/bin/bash
# Configure the timing of automatic updates

echo "=== Maintenance Window Configuration ==="
echo ""

echo "Configuring systemd timer overrides..."
echo ""

# Create override directory for apt-daily timer
mkdir -p /etc/systemd/system/apt-daily.timer.d
cat > /etc/systemd/system/apt-daily.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 02:00
RandomizedDelaySec=30min
EOF

echo "apt-daily.timer:"
echo "  OnCalendar: *-*-* 02:00"
echo "  RandomizedDelaySec: 30min"
echo ""

# Create override directory for apt-daily-upgrade timer
mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d
cat > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:00
RandomizedDelaySec=60min
EOF

echo "apt-daily-upgrade.timer:"
echo "  OnCalendar: *-*-* 03:00"
echo "  RandomizedDelaySec: 60min"
echo ""

echo "Timer configuration:"
echo "  Package list update: 02:00-02:30"
echo "  Package installation: 03:00-04:00"
echo ""

echo "Reloading systemd..."
systemctl daemon-reload 2>/dev/null
systemctl restart apt-daily.timer 2>/dev/null
systemctl restart apt-daily-upgrade.timer 2>/dev/null

echo "Maintenance window configured."
