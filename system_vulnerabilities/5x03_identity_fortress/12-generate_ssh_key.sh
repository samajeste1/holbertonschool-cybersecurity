#!/bin/bash
# Generate a secure SSH key pair with ED25519

echo "=== SSH Key Generation ==="
echo ""

echo "Generating ED25519 key pair..."
echo "  Algorithm: ED25519 (recommended)"
echo "  Key file: ~/.ssh/id_ed25519"
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate key pair
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "$(whoami)@$(hostname)"

echo ""
echo "Key pair generated:"
echo "  Private key: $(readlink -f ~/.ssh/id_ed25519)"
echo "  Public key: $(readlink -f ~/.ssh/id_ed25519.pub)"
echo ""

echo "Setting permissions..."
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
echo "  Private key: 600 (owner read/write only)"
echo "  Public key: 644"
echo ""

echo "Public key fingerprint:"
ssh-keygen -lf ~/.ssh/id_ed25519.pub 2>/dev/null | while read -r line; do
    echo "  $line"
done
echo ""

echo "Your public key:"
cat ~/.ssh/id_ed25519.pub
echo ""

echo "Next step: Add this public key to target servers' authorized_keys"
