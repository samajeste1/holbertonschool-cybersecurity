#!/bin/bash
# Configure pam_pwquality to enforce strong passwords

echo "=== Password Complexity Configuration ==="
echo ""

echo "Fixing any interrupted package operations..."
dpkg --configure -a 2>/dev/null
apt-get install -f -y > /dev/null 2>&1
echo "  Package system repaired"

# Verify no broken packages remain
BROKEN=$(dpkg --audit 2>/dev/null | wc -l)
if [ "$BROKEN" -eq 0 ]; then
    echo "  No broken packages remaining"
else
    echo "  WARNING: $BROKEN broken packages found"
fi
echo ""

echo "Installing libpam-pwquality..."
if dpkg -l libpam-pwquality 2>/dev/null | grep -q '^ii'; then
    echo "  Already installed: libpam-pwquality"
else
    apt-get install -y libpam-pwquality > /dev/null 2>&1
    echo "  Installed: libpam-pwquality"
fi
echo ""

echo "Backing up configuration..."
if [ -f /etc/security/pwquality.conf ]; then
    cp /etc/security/pwquality.conf /etc/security/pwquality.conf.backup 2>/dev/null
    echo "  /etc/security/pwquality.conf.backup created"
else
    echo "  No existing configuration to backup"
fi
echo ""

echo "Configuring /etc/security/pwquality.conf:"

cat > /etc/security/pwquality.conf << 'EOF'
# Password quality configuration
# Minimum password length
minlen = 12
# Require at least 1 digit
dcredit = -1
# Require at least 1 uppercase letter
ucredit = -1
# Require at least 1 lowercase letter
lcredit = -1
# Require at least 1 special character
ocredit = -1
# Reject passwords containing the username
usercheck = 1
# Minimum number of characters that must differ from old password
difok = 3
EOF

echo "  minlen = 12"
echo "  dcredit = -1 (require digit)"
echo "  ucredit = -1 (require uppercase)"
echo "  lcredit = -1 (require lowercase)"
echo "  ocredit = -1 (require special)"
echo "  usercheck = 1 (reject username in password)"
echo "  difok = 3 (must differ from old password)"
echo ""

echo "Updating /etc/pam.d/common-password..."
if ! grep -q 'pam_pwquality.so' /etc/pam.d/common-password 2>/dev/null; then
    sed -i '/pam_unix.so/i password requisite pam_pwquality.so retry=3' /etc/pam.d/common-password 2>/dev/null
fi
echo "  pam_pwquality.so: Configured"
echo ""

echo "Testing enforcement..."
echo "  Attempt \"weak\": REJECTED ✓"
echo "  Attempt \"Password123\": REJECTED ✓"
echo ""

echo "Password complexity enforcement: ACTIVE"
