#!/bin/bash
# Identity and access management hardening functions

harden_identity() {
    log "[INFO] Starting identity hardening"

    # I-01: Password policy via PAM
    if dpkg -l libpam-pwquality &>/dev/null; then
        log "[INFO] libpam-pwquality already installed."
    else
        apt-get install -y libpam-pwquality >> "$LOG_FILE" 2>&1
        log "[INFO] Installed libpam-pwquality."
    fi

    local pwq="/etc/security/pwquality.conf"
    sed -i "s/^#\?\s*minlen\s*=.*/minlen = ${PASS_MIN_LEN}/" "$pwq" 2>/dev/null || echo "minlen = ${PASS_MIN_LEN}" >> "$pwq"
    sed -i "s/^#\?\s*minclass\s*=.*/minclass = 4/" "$pwq" 2>/dev/null || echo "minclass = 4" >> "$pwq"
    log "[INFO] Password policy: minlen=${PASS_MIN_LEN}, minclass=4."

    # Max password age
    sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t${PASS_MAX_DAYS}/" /etc/login.defs
    log "[INFO] Password max age set to ${PASS_MAX_DAYS} days."

    # I-02: Account lockout after failed attempts
    local faillock_cfg="/etc/security/faillock.conf"
    if grep -q "^deny" "$faillock_cfg" 2>/dev/null; then
        sed -i "s/^deny.*/deny = ${FAIL_LOCK_ATTEMPTS}/" "$faillock_cfg"
    else
        echo "deny = ${FAIL_LOCK_ATTEMPTS}" >> "$faillock_cfg"
    fi
    log "[INFO] Account lockout: ${FAIL_LOCK_ATTEMPTS} failed attempts."

    # I-03: Remove unauthorized users (UID > 1000, not in sudo/wheel)
    local removed=0
    local removed_users=""
    while IFS=: read -r username _ uid _; do
        if [ "$uid" -gt 1000 ] && [ "$username" != "nobody" ]; then
            if ! id -nG "$username" 2>/dev/null | grep -qE '\bsudo\b|\bwheel\b'; then
                userdel -r "$username" 2>/dev/null && {
                    removed=$((removed + 1))
                    removed_users="$removed_users $username"
                    log "[INFO] Removed unauthorized user: $username"
                }
            fi
        fi
    done < /etc/passwd
    if [ "$removed" -gt 0 ]; then
        log "[INFO] ${removed} unauthorized users removed:${removed_users}."
    else
        log "[INFO] No unauthorized users found."
    fi

    # I-04: Lock root password
    passwd -l root >> "$LOG_FILE" 2>&1
    log "[INFO] Root account password locked."
}
