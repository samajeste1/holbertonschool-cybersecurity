#!/bin/bash
# SSH hardening functions

harden_ssh() {
    log "[INFO] Starting SSH hardening"

    local cfg="/etc/ssh/sshd_config"

    # S-01: Disable password auth, enable pubkey auth
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$cfg"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$cfg"

    # S-02: Disable root login
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$cfg"

    # Set custom SSH port
    sed -i "s/^#\?Port.*/Port ${SSH_PORT}/" "$cfg"

    log "[INFO] SSH configured on port ${SSH_PORT}."
    log "[INFO] SSH: PasswordAuthentication disabled, PubkeyAuthentication enabled, PermitRootLogin disabled."
}
