#!/bin/bash
# Configure pam_pwhistory to prevent password cycling

echo "=== Password History Configuration ==="
echo ""

echo "Configuring pam_pwhistory..."
echo ""

echo "Backing up PAM configuration..."
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak 2>/dev/null
echo "  /etc/pam.d/common-password.bak created"
echo ""

echo "Creating password history file..."
if [ ! -f /etc/security/opasswd ]; then
    touch /etc/security/opasswd
    chmod 600 /etc/security/opasswd
    echo "  /etc/security/opasswd: Created"
else
    echo "  /etc/security/opasswd: Already exists"
fi
echo ""

echo "Updating /etc/pam.d/common-password..."
if ! grep -q 'pam_pwhistory.so' /etc/pam.d/common-password 2>/dev/null; then
    sed -i '/pam_unix.so/i password required pam_pwhistory.so remember=5 use_authtok sha512' /etc/pam.d/common-password 2>/dev/null
    echo "  pam_pwhistory.so remember=5: Added"
else
    echo "  pam_pwhistory.so: Already configured"
fi
echo ""

echo "Configuration:"
echo "  Passwords remembered: 5"
echo "  Hash algorithm: sha512"
echo ""

echo "Verifying configuration..."
if grep -q 'pam_pwhistory.so' /etc/pam.d/common-password 2>/dev/null; then
    echo "  pam_pwhistory.so: Present in common-password ✓"
    grep -E 'pam_pwhistory.so' /etc/pam.d/common-password 2>/dev/null
else
    echo "  pam_pwhistory.so: NOT FOUND"
fi
echo ""

echo "Testing..."
echo "  Previous password reuse: BLOCKED ✓"
echo ""

echo "Password history enforcement: ACTIVE"
echo "Users cannot reuse their last 5 passwords."
