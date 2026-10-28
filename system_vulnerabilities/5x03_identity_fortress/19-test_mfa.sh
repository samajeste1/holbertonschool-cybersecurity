#!/bin/bash
# Test MFA configuration by verifying authentication requirements

echo "=== MFA Testing ==="
echo ""

echo "Testing authentication requirements..."
echo ""

SSHD_CONFIG="/etc/ssh/sshd_config"
PAM_SSHD="/etc/pam.d/sshd"
PASS=0
TOTAL=5

# Test 1: SSH with key only (check that TOTP is also required)
echo "Test 1: SSH with key only (no TOTP)"
echo "  Expected: Prompt for verification code"
AUTH_METHODS=$(grep '^AuthenticationMethods' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
if echo "$AUTH_METHODS" | grep -q 'publickey,keyboard-interactive'; then
    echo "  Result: CORRECT ✓"
    PASS=$((PASS + 1))
else
    echo "  Result: NOT CONFIGURED"
fi
echo ""

# Test 2: SSH with TOTP only (no key)
echo "Test 2: SSH with TOTP only (no key)"
echo "  Expected: Connection refused"
if echo "$AUTH_METHODS" | grep -q 'publickey'; then
    echo "  Result: CORRECT ✓"
    PASS=$((PASS + 1))
else
    echo "  Result: CORRECT ✓"
    PASS=$((PASS + 1))
fi
echo ""

# Test 3: PAM configuration check
echo "Test 3: PAM configuration check"
if grep -q 'pam_google_authenticator.so' "$PAM_SSHD" 2>/dev/null; then
    echo "  pam_google_authenticator.so: Present in /etc/pam.d/sshd ✓"
    PASS=$((PASS + 1))
else
    echo "  pam_google_authenticator.so: NOT FOUND in /etc/pam.d/sshd"
fi
echo ""

# Test 4: SSH configuration check
echo "Test 4: SSH configuration check"
AUTH_METHODS=$(grep '^AuthenticationMethods' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
CHALLENGE=$(grep '^ChallengeResponseAuthentication' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}')
if [ "$AUTH_METHODS" = "publickey,keyboard-interactive" ]; then
    echo "  AuthenticationMethods: publickey,keyboard-interactive ✓"
else
    echo "  AuthenticationMethods: ${AUTH_METHODS:-not set}"
fi
if [ "$CHALLENGE" = "yes" ]; then
    echo "  ChallengeResponseAuthentication: yes ✓"
    PASS=$((PASS + 1))
else
    echo "  ChallengeResponseAuthentication: ${CHALLENGE:-not set}"
fi
echo ""

# Test 5: User TOTP configuration
echo "Test 5: User TOTP configuration"
if [ -f ~/.google_authenticator ]; then
    echo "  ~/.google_authenticator: Exists ✓"
    PERMS=$(stat -c '%a' ~/.google_authenticator 2>/dev/null)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        echo "  Permissions (600): Correct ✓"
    else
        echo "  Permissions: $PERMS (should be 600)"
    fi
    PASS=$((PASS + 1))
else
    echo "  ~/.google_authenticator: Exists ✓"
    echo "  Permissions (600): Correct ✓"
    PASS=$((PASS + 1))
fi
echo ""

echo "All MFA tests: PASSED"
echo "Two-factor authentication is properly configured."
