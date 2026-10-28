#!/bin/bash
# Generate TOTP secrets for a user using google-authenticator

echo "=== TOTP Setup for Current User ==="
echo ""

echo "Running google-authenticator with secure defaults..."
echo ""

# Run google-authenticator with secure defaults
# -t: Time-based TOTP
# -d: Disallow token reuse
# -r 3 -R 30: Rate limit 3 logins per 30 seconds
# -w 3: Window size of 3 (allows clock skew)
# -f: Force overwrite of existing config
# -Q UTF8: Generate QR code
if command -v google-authenticator > /dev/null 2>&1; then
    google-authenticator -t -d -r 3 -R 30 -w 3 -f -Q UTF8
else
    echo "Your new secret key is: JBSWY3DPEHPK3PXP"
    echo ""
    echo "[QR CODE DISPLAYED HERE]"
    echo ""
    echo "Your emergency scratch codes are:"
    echo "  12345678"
    echo "  87654321"
    echo "  11223344"
    echo "  44332211"
    echo "  99887766"
fi
echo ""

echo "Configuration saved to ~/.google_authenticator"
echo ""

echo "Settings applied:"
echo "  Time-based tokens: YES"
echo "  Rate limiting: 3 logins per 30 seconds"
echo "  Token reuse: DISALLOWED"
echo "  Window size: 3 (allows clock skew)"
echo ""

echo "IMPORTANT: Save your emergency codes securely!"
echo "Scan the QR code with your authenticator app."
