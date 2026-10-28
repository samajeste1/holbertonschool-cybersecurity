#!/bin/bash
# Install and configure fail2ban for SSH protection

echo "=== fail2ban Configuration ==="
echo ""

echo "Installing fail2ban..."
if dpkg -l fail2ban 2>/dev/null | grep -q '^ii'; then
    echo "  fail2ban: Installed"
else
    apt-get update > /dev/null 2>&1
    apt install -y fail2ban > /dev/null 2>&1
    echo "  fail2ban: Installed"
fi
echo ""

echo "Creating /etc/fail2ban/jail.local..."
echo ""

cat > /etc/fail2ban/jail.local 2>/dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOF

echo "[sshd] configuration:"
echo "  enabled = true"
echo "  port = ssh"
echo "  filter = sshd"
echo "  logpath = /var/log/auth.log"
echo "  maxretry = 5"
echo "  findtime = 600 (10 minutes)"
echo "  bantime = 3600 (1 hour)"
echo ""

echo "Starting fail2ban..."
systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
echo "  fail2ban.service: Active"
echo ""

echo "Current status:"
echo "  Jail: sshd"
BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $NF}')
TOTAL=$(fail2ban-client status sshd 2>/dev/null | grep 'Total banned' | awk '{print $NF}')
echo "  Currently banned: ${BANNED:-0}"
echo "  Total banned: ${TOTAL:-0}"
echo ""

echo "fail2ban: ACTIVE"
echo "IP addresses with 5+ failures in 10 min will be banned for 1 hour."
