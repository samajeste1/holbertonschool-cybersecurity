#!/bin/bash
# Configure a legal warning banner for SSH access

echo "=== Legal Banner Configuration ==="
echo ""

echo "Creating banner in /etc/issue.net..."
echo ""

# Create the legal banner
cat > /etc/issue.net << 'BANNER'
=====================================
AUTHORIZED ACCESS ONLY

This system is the property of NovaTech Solutions.
Unauthorized access is prohibited and will be prosecuted.
All activities are monitored and logged.
=====================================
BANNER

echo "Banner content:"
cat /etc/issue.net
echo ""

echo "Configuring SSH to display banner..."

# Enable banner in sshd_config
if grep -q '^Banner' /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config 2>/dev/null
elif grep -q '^#Banner' /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^#Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config 2>/dev/null
else
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config 2>/dev/null
fi
echo "  Banner /etc/issue.net: Enabled"
echo ""

echo "Reloading SSH..."
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
echo ""

echo "Verification:"

# Check banner file exists
if [ -f /etc/issue.net ]; then
    echo "  /etc/issue.net: EXISTS"
else
    echo "  /etc/issue.net: MISSING"
fi

# Check SSH config
if grep -q 'Banner /etc/issue.net' /etc/ssh/sshd_config 2>/dev/null; then
    echo "  SSH Banner config: ENABLED"
else
    echo "  SSH Banner config: NOT SET"
fi
echo ""

echo "Legal banner configured."
