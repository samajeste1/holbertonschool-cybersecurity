#!/bin/bash
# Identity and access management hardening functions: password
# quality, password aging, account lockout, unauthorized accounts,
# root password lock.

# I-01: password complexity (pam_pwquality) and maximum age.
enforce_password_policy() {
    if ! is_installed libpam-pwquality; then
        if apt-get install -y libpam-pwquality >> "$LOG_FILE" 2>&1; then
            log INFO "Installed libpam-pwquality."
        else
            log ERROR "Failed to install libpam-pwquality."
            return 1
        fi
    fi

    # Complexity: minimum length + at least one upper, lower, digit, special.
    local option
    set_option "$PWQUALITY_CONF" "minlen" " = " "$PASS_MIN_LEN" || return 1
    set_option "$PWQUALITY_CONF" "minclass" " = " "$PASS_MIN_CLASS"
    for option in ucredit lcredit dcredit ocredit; do
        set_option "$PWQUALITY_CONF" "$option" " = " "-1"
    done

    # Same rules on the PAM line itself (/etc/pam.d/common-password).
    local pam_args="retry=3 minlen=${PASS_MIN_LEN} ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root"
    if grep -qE '^[[:space:]]*password[[:space:]].*pam_pwquality\.so' "$PAM_COMMON_PASSWORD" 2>/dev/null; then
        [ -f "${PAM_COMMON_PASSWORD}.orig" ] || cp -p "$PAM_COMMON_PASSWORD" "${PAM_COMMON_PASSWORD}.orig"
        sed -i -E "s|^([[:space:]]*password[[:space:]]+[^[:space:]]+[[:space:]]+pam_pwquality\.so).*|\1 ${pam_args}|" \
            "$PAM_COMMON_PASSWORD"
    else
        log ERROR "pam_pwquality.so not found in $PAM_COMMON_PASSWORD."
        return 1
    fi

    # Aging.
    set_option "$LOGIN_DEFS" "PASS_MAX_DAYS" $'\t' "$PASS_MAX_DAYS" || return 1
    set_option "$LOGIN_DEFS" "PASS_MIN_LEN" $'\t' "$PASS_MIN_LEN"

    report "Password policy enforced: minlen=${PASS_MIN_LEN}, upper+lower+digit+special required, max age=${PASS_MAX_DAYS} days."
}

# I-02: lock accounts after FAIL_LOCK_ATTEMPTS failed logins
# (pam_faillock in common-auth and common-account).
enforce_account_lockout() {
    local options="deny=${FAIL_LOCK_ATTEMPTS} unlock_time=${FAIL_LOCK_UNLOCK_TIME}"
    local tmp

    set_option "$FAILLOCK_CONF" "deny" " = " "$FAIL_LOCK_ATTEMPTS" || return 1
    set_option "$FAILLOCK_CONF" "unlock_time" " = " "$FAIL_LOCK_UNLOCK_TIME"

    if [ ! -f "$PAM_COMMON_AUTH" ] || [ ! -f "$PAM_COMMON_ACCOUNT" ]; then
        log ERROR "PAM files missing: $PAM_COMMON_AUTH / $PAM_COMMON_ACCOUNT"
        return 1
    fi
    [ -f "${PAM_COMMON_AUTH}.orig" ] || cp -p "$PAM_COMMON_AUTH" "${PAM_COMMON_AUTH}.orig"

    # Drop any previous pam_faillock line, then wrap pam_unix with the
    # preauth / authfail / authsucc lines (same result on every run).
    tmp=$(mktemp) || { log ERROR "mktemp failed."; return 1; }
    if awk -v opts="$options" '
        /pam_faillock\.so/ { next }
        /^auth[[:space:]].*pam_unix\.so/ && !done {
            print "auth\trequired\t\t\tpam_faillock.so preauth " opts
            print
            print "auth\t[default=die]\t\t\tpam_faillock.so authfail " opts
            print "auth\tsufficient\t\t\tpam_faillock.so authsucc " opts
            done = 1
            next
        }
        { print }
        END { exit done ? 0 : 1 }' "$PAM_COMMON_AUTH" > "$tmp"; then
        cat "$tmp" > "$PAM_COMMON_AUTH"
    else
        rm -f "$tmp"
        log ERROR "pam_unix.so not found in $PAM_COMMON_AUTH: lockout not configured."
        return 1
    fi
    rm -f "$tmp"

    if ! grep -q "pam_faillock\.so" "$PAM_COMMON_ACCOUNT"; then
        printf 'account\trequired\t\t\tpam_faillock.so\n' >> "$PAM_COMMON_ACCOUNT"
    fi
    report "Account lockout set to ${FAIL_LOCK_ATTEMPTS} failed attempts (pam_faillock, unlock after ${FAIL_LOCK_UNLOCK_TIME}s)."
}

# is_protected USER - true if USER must be kept (SSH users, the admin
# running the script, members of an admin group).
is_protected() {
    local user="$1" allowed group
    for allowed in $ALLOWED_SSH_USERS ${SUDO_USER:-}; do
        [ "$user" = "$allowed" ] && return 0
    done
    for group in $ADMIN_GROUPS; do
        id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group" && return 0
    done
    return 1
}

# I-03: delete users with UID > USER_UID_THRESHOLD not in sudo/wheel.
remove_unauthorized_users() {
    local candidates=() removed=() username uid
    while IFS=: read -r username _ uid _; do
        [ "$uid" -gt "$USER_UID_THRESHOLD" ] && [ "$uid" -lt "$NOBODY_UID" ] || continue
        is_protected "$username" || candidates+=("$username")
    done < "$PASSWD_FILE"

    for username in "${candidates[@]}"; do
        userdel -r "$username" >> "$LOG_FILE" 2>&1
        if id "$username" &>/dev/null; then
            log ERROR "Failed to remove unauthorized user: $username"
        else
            removed+=("$username")
            log INFO "Removed unauthorized user: $username"
        fi
    done

    if [ "${#removed[@]}" -gt 0 ]; then
        report "${#removed[@]} unauthorized users removed: $(join_by ", " "${removed[@]}")."
    elif [ "${#candidates[@]}" -eq 0 ]; then
        report "0 unauthorized users removed (none found)."
    fi
}

# I-04: lock the root password (root must use sudo).
lock_root_password() {
    if passwd -S root 2>/dev/null | awk '{ exit ($2 == "L") ? 0 : 1 }'; then
        report "Root account password already locked."
    elif passwd -l root >> "$LOG_FILE" 2>&1; then
        report "Root account password locked."
    else
        log ERROR "Failed to lock root password."
    fi
}

harden_identity() {
    log INFO "Starting identity hardening."
    enforce_password_policy
    enforce_account_lockout
    remove_unauthorized_users
    lock_root_password
}
