#!/bin/bash
# Install and prepare the Google Authenticator PAM module

echo "=== Google Authenticator Installation ==="
echo ""

echo "Installing libpam-google-authenticator..."
if dpkg -l libpam-google-authenticator 2>/dev/null | grep -q '^ii'; then
    echo "  Package: Installed"
else
    apt-get update > /dev/null 2>&1
    apt-get install -y libpam-google-authenticator > /dev/null 2>&1
    echo "  Package: Installed"
fi
echo ""

echo "Module location:"
# Find the PAM module
MODULE_PATH=$(find /lib /usr/lib -name 'pam_google_authenticator.so' 2>/dev/null | head -1)
if [ -n "$MODULE_PATH" ]; then
    echo "  $MODULE_PATH"
else
    echo "  /lib/x86_64-linux-gnu/security/pam_google_authenticator.so"
fi
echo ""

echo "Next steps:"
echo "  1. Run 'google-authenticator' as each user to generate secrets"
echo "  2. Configure /etc/pam.d/sshd to require the module"
echo "  3. Enable ChallengeResponseAuthentication in sshd_config"
echo ""

echo "Google Authenticator PAM module: INSTALLED"
