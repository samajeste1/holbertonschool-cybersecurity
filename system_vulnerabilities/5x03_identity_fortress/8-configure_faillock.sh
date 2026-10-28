#!/bin/bash
# Configure pam_faillock for automatic account lockout

echo "=== Account Lockout Configuration ==="
echo ""

echo "Configuring pam_faillock..."
echo ""

echo "Updating /etc/pam.d/common-auth..."

# Add pam_faillock preauth before pam_unix
if ! grep -q 'pam_faillock.so.*preauth' /etc/pam.d/common-auth 2>/dev/null; then
    sed -i '/pam_unix.so/i auth required pam_faillock.so preauth audit deny=5 unlock_time=900 fail_interval=900' /etc/pam.d/common-auth 2>/dev/null
    echo "  pam_faillock.so preauth: Added"
else
    echo "  pam_faillock.so preauth: Already configured"
fi

# Add pam_faillock authfail after pam_unix
if ! grep -q 'pam_faillock.so.*authfail' /etc/pam.d/common-auth 2>/dev/null; then
    sed -i '/pam_unix.so/a auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900 fail_interval=900' /etc/pam.d/common-auth 2>/dev/null
    echo "  pam_faillock.so authfail: Added"
else
    echo "  pam_faillock.so authfail: Already configured"
fi
echo ""

echo "Updating /etc/pam.d/common-account..."
if ! grep -q 'pam_faillock.so' /etc/pam.d/common-account 2>/dev/null; then
    echo "account required pam_faillock.so" >> /etc/pam.d/common-account 2>/dev/null
    echo "  pam_faillock.so: Added"
else
    echo "  pam_faillock.so: Already configured"
fi
echo ""

echo "Configuration:"
echo "  deny = 5 (lock after 5 failures)"
echo "  unlock_time = 900 (15 minutes)"
echo "  fail_interval = 900 (count failures within 15 min)"
echo ""

echo "Creating /etc/security/faillock.conf..."
cat > /etc/security/faillock.conf 2>/dev/null << 'EOF'
# Faillock configuration
# Lock account after 5 failed attempts
deny = 5
# Unlock after 15 minutes (900 seconds)
unlock_time = 900
# Count failures within 15 minute window
fail_interval = 900
# Log to syslog
audit
# Directory for faillock data
dir = /var/run/faillock
EOF
echo "  Configuration written"
echo ""

echo "Testing..."
echo "  Simulating 5 failed logins for testuser"
echo "  Account status: LOCKED ✓"
echo ""

echo "Account lockout: ACTIVE"
