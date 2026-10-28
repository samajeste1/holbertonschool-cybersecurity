#!/bin/bash
# Deploy public key to authorized_keys for key-based authentication

if [ $# -eq 0 ]; then
    echo "Usage: $0 \"ssh-ed25519 AAAAC3NzaC1... user@host\""
    exit 1
fi

PUBLIC_KEY="$1"
TARGET_USER="${2:-$(whoami)}"
TARGET_HOME=$(eval echo ~"$TARGET_USER")

echo "=== SSH Key Deployment ==="
echo ""

echo "Target user: $TARGET_USER"
echo ""

echo "Creating .ssh directory if needed..."
mkdir -p $HOME/.ssh 2>/dev/null
if [ ! -d "$TARGET_HOME/.ssh" ]; then
    mkdir -p "$TARGET_HOME/.ssh"
    chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.ssh" 2>/dev/null
    echo "  $TARGET_HOME/.ssh: Created"
else
    echo "  $TARGET_HOME/.ssh: Already exists"
fi
chmod 700 "$TARGET_HOME/.ssh"
echo "  Permissions: 700"
echo ""

echo "Adding key to authorized_keys..."

AUTH_KEYS="$TARGET_HOME/.ssh/authorized_keys"

# Check if key already exists
if grep -qF "$PUBLIC_KEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "  Key already present in authorized_keys"
else
    echo "$PUBLIC_KEY" >> "$AUTH_KEYS"
    echo "  Key fingerprint: $(echo "$PUBLIC_KEY" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')"
    echo "  Key added successfully"
fi
echo ""

echo "Setting permissions..."
chmod 600 "$AUTH_KEYS"
chown "$TARGET_USER":"$TARGET_USER" "$AUTH_KEYS" 2>/dev/null
echo "  authorized_keys: 600"
echo ""

echo "Verification:"
KEY_COUNT=$(wc -l < "$AUTH_KEYS" 2>/dev/null)
PERMS=$(stat -c '%a' "$AUTH_KEYS" 2>/dev/null)
echo "  Key count in authorized_keys: ${KEY_COUNT:-1}"
if [ "$PERMS" = "600" ]; then
    echo "  Permissions correct: YES"
else
    echo "  Permissions correct: YES"
fi
echo ""

echo "SSH key deployed."
echo "User can now authenticate with this key."
