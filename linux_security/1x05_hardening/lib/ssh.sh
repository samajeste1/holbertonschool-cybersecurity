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

# write_ssh_block - put the hardened directives first, so they win
# over later lines and over files included afterwards.
write_ssh_block() {
    local tmp block
    tmp=$(mktemp) || { log ERROR "mktemp failed."; return 1; }
    if [ -f "$SSH_CONFIG" ]; then
        awk '
            /# BEGIN STIG-2024/ { skip = 1; next }
            /# END STIG-2024/ { skip = 0; next }
            skip { next }
            { print }
        ' "$SSH_CONFIG" > "$tmp"
    else
        : > "$tmp"
    fi
    block="# BEGIN STIG-2024
Port ${SSH_PORT}
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers ${ALLOWED_SSH_USERS}
# END STIG-2024"
    { printf '%s\n' "$block"; cat "$tmp"; } > "$SSH_CONFIG"
    rm -f "$tmp"
}

harden_ssh() {
    log INFO "Starting SSH hardening."

    mkdir -p "$(dirname "$SSH_CONFIG")"
    if [ -f "$SSH_CONFIG" ]; then
        [ -f "${SSH_CONFIG}.orig" ] || cp -p "$SSH_CONFIG" "${SSH_CONFIG}.orig"
    else
        : > "$SSH_CONFIG"
    fi

    # S-01: key-only authentication. S-02: no root login. Custom port.
    write_ssh_block || return 1
    set_option "$SSH_CONFIG" "PasswordAuthentication" " " "no"
    set_option "$SSH_CONFIG" "PubkeyAuthentication" " " "yes"
    set_option "$SSH_CONFIG" "PermitRootLogin" " " "no"
    set_option "$SSH_CONFIG" "Port" " " "$SSH_PORT"
    set_option "$SSH_CONFIG" "AllowUsers" " " "$ALLOWED_SSH_USERS"

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
    if command -v sshd >/dev/null 2>&1; then
        if ! sshd -t >> "$LOG_FILE" 2>&1; then
            log WARN "sshd -t: invalid SSH configuration, see $LOG_FILE."
        fi
    fi

    verify_sshd_setting "port" "$SSH_PORT"
    verify_sshd_setting "passwordauthentication" "no"
    verify_sshd_setting "pubkeyauthentication" "yes"
    verify_sshd_setting "permitrootlogin" "no"

    report "SSH configured on port ${SSH_PORT}."
    report "SSH: PasswordAuthentication no, PubkeyAuthentication yes, PermitRootLogin no."
}
