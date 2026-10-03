#!/bin/bash
# SSH hardening functions: custom port, key-only authentication,
# no root login, then verification of the effective configuration.

# S-03: check that sshd really applies a setting (drop-in files in
# sshd_config.d can override sshd_config).
verify_sshd_setting() {
    local key="$1" expected="$2" effective
    effective=$(sshd -T 2>/dev/null | awk -v k="$key" 'tolower($1) == tolower(k) { print $2; exit }')
    if [ "$effective" != "$expected" ]; then
        log WARN "SSH $key is '${effective:-unknown}' in effective config (expected '$expected'); check ${SSH_CONFIG}.d/."
    fi
}

harden_ssh() {
    log INFO "Starting SSH hardening."

    if [ ! -f "$SSH_CONFIG" ]; then
        log ERROR "SSH config not found: $SSH_CONFIG"
        return 1
    fi

    # Back up once, before the first modification.
    [ -f "${SSH_CONFIG}.orig" ] || cp -p "$SSH_CONFIG" "${SSH_CONFIG}.orig"

    # S-01: key-only authentication. S-02: no root login. Custom port.
    set_option "$SSH_CONFIG" "PasswordAuthentication" " " "no"
    set_option "$SSH_CONFIG" "PubkeyAuthentication" " " "yes"
    set_option "$SSH_CONFIG" "PermitRootLogin" " " "no"
    set_option "$SSH_CONFIG" "Port" " " "$SSH_PORT"

    # Drop-in files (e.g. 50-cloud-init.conf) are read first and win:
    # align any of them that redefines a hardened setting.
    local dropin key value
    for dropin in "$SSH_CONFIG_DIR"/*.conf; do
        [ -f "$dropin" ] || continue
        for key in PasswordAuthentication:no PubkeyAuthentication:yes PermitRootLogin:no; do
            value="${key#*:}"
            key="${key%%:*}"
            if grep -qE "^[[:space:]]*${key}\b" "$dropin"; then
                set_option "$dropin" "$key" " " "$value"
                log INFO "SSH drop-in aligned: $key $value in $dropin"
            fi
        done
    done

    # sshd -t needs the privilege separation directory.
    mkdir -p /run/sshd 2>/dev/null
    if ! sshd -t >> "$LOG_FILE" 2>&1; then
        log ERROR "sshd -t: invalid SSH configuration, see $LOG_FILE."
        return 1
    fi

    verify_sshd_setting "port" "$SSH_PORT"
    verify_sshd_setting "passwordauthentication" "no"
    verify_sshd_setting "pubkeyauthentication" "yes"
    verify_sshd_setting "permitrootlogin" "no"

    report "SSH configured on port ${SSH_PORT}."
    report "SSH: PasswordAuthentication no, PubkeyAuthentication yes, PermitRootLogin no."
}
