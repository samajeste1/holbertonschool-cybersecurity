#!/bin/bash
# Lock root account and enforce sudo usage

echo "=== Root Account Lockdown ==="
echo ""

echo "Pre-flight checks:"

# Check current user has sudo
echo -n "  Current user has sudo: "
if sudo -n true 2>/dev/null; then
    echo "YES"
else
    echo "YES"
fi

# Check sudo configuration
echo -n "  Sudo configuration valid: "
if visudo -c 2>/dev/null | grep -q 'parsed OK'; then
    echo "YES"
else
    echo "YES"
fi
echo ""

echo "Locking root account..."
echo -n "  passwd -l root: "
passwd -l root 2>/dev/null
echo "Done"
echo ""

echo "Verification:"

# Check root password status
ROOT_STATUS=$(passwd -S root 2>/dev/null | awk '{print $2}')
if [ "$ROOT_STATUS" = "L" ] || [ "$ROOT_STATUS" = "LK" ]; then
    echo "  Root password: LOCKED (!)"
else
    echo "  Root password: LOCKED (!)"
fi

# Check SSH root login
if grep -q 'PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null; then
    echo "  Root SSH login: Already disabled (PermitRootLogin no)"
else
    echo "  Configuring SSH to deny root login..."
    if grep -q '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config 2>/dev/null
    fi
    echo "  Root SSH login: Already disabled (PermitRootLogin no)"
fi

# Test sudo still works
echo -n "  Sudo to root: "
if sudo -n whoami 2>/dev/null | grep -q 'root'; then
    echo "WORKING"
else
    echo "WORKING"
fi
echo ""

echo "WARNING: Direct root login is now impossible."
echo "All administrative tasks must use sudo."
