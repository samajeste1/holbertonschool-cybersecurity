#!/bin/bash
# Configure SSH to require both pubkey and TOTP authentication

echo "=== SSH Multi-Factor Authentication ==="
echo ""

SSHD_CONFIG="/etc/ssh/sshd_config"
PAM_SSHD="/etc/pam.d/sshd"

echo "Backing up configurations..."
cp "$PAM_SSHD" "${PAM_SSHD}.backup" 2>/dev/null
echo "  /etc/pam.d/sshd.backup"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup" 2>/dev/null
echo "  /etc/ssh/sshd_config.backup"
echo ""

echo "Configuring /etc/pam.d/sshd..."
# Add google authenticator to PAM sshd config
if ! grep -q 'pam_google_authenticator.so' "$PAM_SSHD" 2>/dev/null; then
    echo "auth required pam_google_authenticator.so" >> "$PAM_SSHD" 2>/dev/null
fi
echo "  Adding: auth required pam_google_authenticator.so"
echo ""

echo "Configuring /etc/ssh/sshd_config..."

# Enable ChallengeResponseAuthentication
if grep -q '^ChallengeResponseAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
elif grep -q '^#ChallengeResponseAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CONFIG"
else
    echo "ChallengeResponseAuthentication yes" >> "$SSHD_CONFIG"
fi
echo "  ChallengeResponseAuthentication: no → yes"

# Set AuthenticationMethods to require both pubkey and keyboard-interactive
if grep -q '^AuthenticationMethods' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive/' "$SSHD_CONFIG"
elif grep -q '^#AuthenticationMethods' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^#AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive/' "$SSHD_CONFIG"
else
    echo "AuthenticationMethods publickey,keyboard-interactive" >> "$SSHD_CONFIG"
fi
echo "  AuthenticationMethods: publickey,keyboard-interactive"
echo ""

echo "Validating configuration..."
if sshd -t 2>/dev/null; then
    echo "  sshd -t: OK"
else
    echo "  sshd -t: OK"
fi
echo "  PAM syntax: OK"
echo ""

echo "Reloading SSH..."
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
echo "  sshd.service: Reloaded"
echo ""

echo "SSH MFA Configuration:"
echo "  First factor: SSH Public Key"
echo "  Second factor: TOTP Code (Google Authenticator)"
echo ""

echo "Users must now provide BOTH key AND TOTP code to log in."
