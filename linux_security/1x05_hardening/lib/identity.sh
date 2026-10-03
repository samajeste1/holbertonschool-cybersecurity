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
    set_option "$PWQUALITY_CONF" "minlen" " = " "$PASS_MIN_LEN" &&
        set_option "$PWQUALITY_CONF" "minclass" " = " "$PASS_MIN_CLASS" &&
        set_option "$LOGIN_DEFS" "PASS_MAX_DAYS" $'\t' "$PASS_MAX_DAYS" &&
        report "Password policy enforced: minlen=${PASS_MIN_LEN}, minclass=${PASS_MIN_CLASS}, max age=${PASS_MAX_DAYS} days."
}

# I-02: lock accounts after FAIL_LOCK_ATTEMPTS failed logins.
enforce_account_lockout() {
    set_option "$FAILLOCK_CONF" "deny" " = " "$FAIL_LOCK_ATTEMPTS" || return 1
    report "Account lockout set to ${FAIL_LOCK_ATTEMPTS} failed attempts."
    if ! grep -q "pam_faillock" "$PAM_COMMON_AUTH" 2>/dev/null; then
        log WARN "pam_faillock is not enabled in $PAM_COMMON_AUTH: lockout not active."
    fi
}

# is_authorized USER - true if USER must be kept.
is_authorized() {
    local user="$1" allowed group
    for allowed in $AUTHORIZED_USERS $ALLOWED_SSH_USERS ${SUDO_USER:-}; do
        [ "$user" = "$allowed" ] && return 0
    done
    for group in $ADMIN_GROUPS; do
        id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group" && return 0
    done
    return 1
}

# I-03: delete regular accounts that are not authorized.
remove_unauthorized_users() {
    local candidates=() removed=() username uid
    while IFS=: read -r username _ uid _; do
        [ "$uid" -ge "$MIN_USER_UID" ] && [ "$uid" -lt 65534 ] || continue
        is_authorized "$username" || candidates+=("$username")
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
    else
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
