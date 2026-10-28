#!/bin/bash
# Configure password aging policies

echo "=== Password Aging Configuration ==="
echo ""

echo "Configuring /etc/login.defs..."

if [ -f /etc/login.defs ]; then
    # Get current values
    OLD_MAX=$(grep '^PASS_MAX_DAYS' /etc/login.defs | awk '{print $2}')
    OLD_MIN=$(grep '^PASS_MIN_DAYS' /etc/login.defs | awk '{print $2}')
    OLD_WARN=$(grep '^PASS_WARN_AGE' /etc/login.defs | awk '{print $2}')
    OLD_MAX=${OLD_MAX:-99999}
    OLD_MIN=${OLD_MIN:-0}
    OLD_WARN=${OLD_WARN:-7}

    # Update PASS_MAX_DAYS
    if grep -q '^PASS_MAX_DAYS' /etc/login.defs; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
    else
        echo "PASS_MAX_DAYS	90" >> /etc/login.defs
    fi

    # Update PASS_MIN_DAYS
    if grep -q '^PASS_MIN_DAYS' /etc/login.defs; then
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t1/' /etc/login.defs
    else
        echo "PASS_MIN_DAYS	1" >> /etc/login.defs
    fi

    # Update PASS_WARN_AGE
    if grep -q '^PASS_WARN_AGE' /etc/login.defs; then
        sed -i "s/^PASS_WARN_AGE.*/PASS_WARN_AGE\t14/" /etc/login.defs
    else
        echo "PASS_WARN_AGE	14" >> /etc/login.defs
    fi

    echo "  PASS_MAX_DAYS: $OLD_MAX → 90"
    echo "  PASS_MIN_DAYS: $OLD_MIN → 1"
    echo "  PASS_WARN_AGE: $OLD_WARN → 14"
else
    echo "  /etc/login.defs not found"
fi
echo ""

echo "Note: These settings apply to NEW accounts only."
echo "Existing accounts must be updated with chage."
echo ""

echo "Applying to existing users..."
# Apply to existing human users (UID >= 1000, not nobody)
while IFS=: read -r username _ uid _ _ _ shell; do
    if [ "$uid" -ge 1000 ] 2>/dev/null && [ "$username" != "nobody" ] && [ "$shell" != "/usr/sbin/nologin" ] && [ "$shell" != "/bin/false" ]; then
        chage -M 90 -m 1 -W 14 "$username" 2>/dev/null
        echo "  $username: Max=90, Min=1, Warn=14"
    fi
done < /etc/passwd

echo "  [Skipping system accounts]"
echo ""

echo "Password aging: CONFIGURED"
