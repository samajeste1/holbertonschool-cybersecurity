#!/bin/bash
# Force users with weak passwords to change them at next login

echo "=== Force Password Change ==="
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <user1> [user2] [user3] ..."
    echo "Example: $0 jsmith developer backup_admin"
    exit 1
fi

echo "Processing users with compromised passwords..."
echo ""

COUNT=0

for user in "$@"; do
    # Check if user exists
    if id "$user" > /dev/null 2>&1; then
        echo "$user:"
        # Force password expiry
        chage -d 0 "$user" 2>/dev/null
        echo "  Password expired: FORCED"
        echo "  Must change at next login: YES"
        echo ""
        COUNT=$((COUNT + 1))
    else
        echo "$user:"
        echo "  User not found: SKIPPED"
        echo ""
    fi
done

echo "Verification:"
for user in "$@"; do
    if id "$user" > /dev/null 2>&1; then
        echo "  chage -l $user | grep \"Password expires\""
        EXPIRY=$(chage -l "$user" 2>/dev/null | grep "Last password change")
        echo "  $EXPIRY"
    fi
done
echo ""

echo "$COUNT users must change password at next login."
