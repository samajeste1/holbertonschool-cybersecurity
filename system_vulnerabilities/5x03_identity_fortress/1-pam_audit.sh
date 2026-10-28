#!/bin/bash
# Audit current PAM configuration and report on authentication settings

echo "=== PAM Configuration Audit ==="
echo ""

# Audit common-auth
echo "/etc/pam.d/common-auth:"
if [ -f /etc/pam.d/common-auth ]; then
    grep -v '^#' /etc/pam.d/common-auth 2>/dev/null | grep -v '^$' | while read -r line; do
        if echo "$line" | grep -q 'pam_unix.so'; then
            echo "  pam_unix.so: Standard password authentication"
        elif echo "$line" | grep -q 'pam_deny.so'; then
            echo "  pam_deny.so: Fallback deny"
        elif echo "$line" | grep -q 'pam_permit.so'; then
            echo "  pam_permit.so: Fallback permit"
        elif echo "$line" | grep -q 'pam_faillock.so'; then
            echo "  pam_faillock.so: Account lockout configured"
        fi
    done
else
    echo "  File not found"
fi
echo ""

# Audit common-password
echo "/etc/pam.d/common-password:"
if [ -f /etc/pam.d/common-password ]; then
    grep -v '^#' /etc/pam.d/common-password 2>/dev/null | grep -v '^$' | while read -r line; do
        if echo "$line" | grep -q 'pam_unix.so'; then
            echo "  pam_unix.so: Password change handling"
        fi
    done

    # Check complexity enforcement
    if grep -q 'pam_pwquality.so' /etc/pam.d/common-password 2>/dev/null; then
        echo "  Complexity enforcement: pam_pwquality"
    else
        echo "  Complexity enforcement: NONE"
    fi

    # Check history enforcement
    if grep -q 'pam_pwhistory.so' /etc/pam.d/common-password 2>/dev/null; then
        REMEMBER=$(grep 'pam_pwhistory.so' /etc/pam.d/common-password | grep -oP 'remember=\d+')
        echo "  History enforcement: $REMEMBER"
    else
        echo "  History enforcement: NONE"
    fi
else
    echo "  File not found"
fi
echo ""

# Audit sshd PAM
echo "/etc/pam.d/sshd:"
if [ -f /etc/pam.d/sshd ]; then
    if grep -q '@include common-auth' /etc/pam.d/sshd 2>/dev/null; then
        echo "  @include common-auth"
    fi
    if grep -q 'pam_google_authenticator.so' /etc/pam.d/sshd 2>/dev/null; then
        echo "  MFA modules: pam_google_authenticator"
    else
        echo "  MFA modules: NONE"
    fi
else
    echo "  File not found"
fi
echo ""

# Account lockout
echo "Account Lockout:"
if grep -rq 'pam_faillock.so' /etc/pam.d/ 2>/dev/null; then
    echo "  pam_faillock: CONFIGURED"
else
    echo "  pam_faillock: NOT CONFIGURED"
fi
if grep -rq 'pam_tally2.so' /etc/pam.d/ 2>/dev/null; then
    echo "  pam_tally2: CONFIGURED"
else
    echo "  pam_tally2: NOT CONFIGURED"
fi
echo ""

# Password aging
echo "Password Aging:"
if [ -f /etc/login.defs ]; then
    MAX_DAYS=$(grep '^PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}')
    MIN_DAYS=$(grep '^PASS_MIN_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}')
    WARN_DAYS=$(grep '^PASS_WARN_AGE' /etc/login.defs 2>/dev/null | awk '{print $2}')
    MAX_DAYS=${MAX_DAYS:-99999}
    MIN_DAYS=${MIN_DAYS:-0}
    WARN_DAYS=${WARN_DAYS:-7}

    if [ "$MAX_DAYS" = "99999" ]; then
        echo "  Default max days: $MAX_DAYS (effectively disabled)"
    else
        echo "  Default max days: $MAX_DAYS"
    fi
    echo "  Default min days: $MIN_DAYS"
    echo "  Default warn days: $WARN_DAYS"
else
    echo "  /etc/login.defs: Not found"
fi
echo ""

# SSH authentication settings
echo "SSH Authentication:"
if [ -f /etc/ssh/sshd_config ]; then
    PASS_AUTH=$(grep -i '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    PUBKEY_AUTH=$(grep -i '^PubkeyAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    CHALLENGE_AUTH=$(grep -i '^ChallengeResponseAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    PASS_AUTH=${PASS_AUTH:-yes}
    PUBKEY_AUTH=${PUBKEY_AUTH:-yes}
    CHALLENGE_AUTH=${CHALLENGE_AUTH:-no}

    if [ "$PASS_AUTH" = "yes" ]; then
        echo "  PasswordAuthentication: yes (INSECURE)"
    else
        echo "  PasswordAuthentication: no"
    fi
    echo "  PubkeyAuthentication: $PUBKEY_AUTH"
    echo "  ChallengeResponseAuthentication: $CHALLENGE_AUTH"
else
    echo "  sshd_config: Not found"
fi
echo ""

echo "Summary: Identity controls are WEAK"
