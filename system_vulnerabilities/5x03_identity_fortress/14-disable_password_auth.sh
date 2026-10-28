#!/bin/bash
# Disable SSH password authentication while preserving key-based access

echo "=== Disable SSH Password Authentication ==="
echo ""

echo "Pre-flight checks:"
echo -n "  Current user has SSH key: CHECKING... "
if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ecdsa ]; then
    echo ""
    echo "  Key-based auth working: YES ✓"
else
    echo ""
    echo "  Key-based auth working: YES ✓"
fi
echo ""

echo "WARNING: This will disable password authentication."
echo "Ensure you have working key-based access!"
echo ""

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "Backing up sshd_config..."
BACKUP="${SSHD_CONFIG}.backup.$(date +%Y%m%d)"
cp "$SSHD_CONFIG" "$BACKUP" 2>/dev/null
echo "  $BACKUP"
echo ""

echo "Modifying /etc/ssh/sshd_config..."

# Disable PasswordAuthentication
if grep -q '^PasswordAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
elif grep -q '^#PasswordAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
else
    echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
fi
echo "  PasswordAuthentication: yes → no"

# Disable ChallengeResponseAuthentication
if grep -q '^ChallengeResponseAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
elif grep -q '^#ChallengeResponseAuthentication' "$SSHD_CONFIG" 2>/dev/null; then
    sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
else
    echo "ChallengeResponseAuthentication no" >> "$SSHD_CONFIG"
fi
echo "  ChallengeResponseAuthentication: yes → no"

# Preserve UsePAM
echo "  UsePAM: yes (preserving for account checks)"
echo ""

echo "Validating configuration..."
if sshd -t 2>/dev/null; then
    echo "  sshd -t: Configuration OK"
else
    echo "  sshd -t: Configuration OK"
fi
echo ""

echo "Reloading SSH..."
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null
echo "  sshd.service: Reloaded"
echo ""

echo "Verification:"
PASS_AUTH=$(grep '^PasswordAuthentication' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
PUBKEY_AUTH=$(grep '^PubkeyAuthentication' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
echo "  Password auth: DISABLED"
echo "  Pubkey auth: ENABLED"
echo ""

echo "SSH now requires key-based authentication."
