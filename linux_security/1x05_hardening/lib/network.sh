#!/bin/bash
# Network hardening functions: firewall policy file and kernel
# network parameters.

# N-01 / N-02: write the firewall policy (default deny inbound,
# allow SSH and the web ports enabled in the configuration).
create_firewall_policy() {
    local ports=("$SSH_PORT")
    [ "$ALLOW_HTTP" = "yes" ] && ports+=("$HTTP_PORT")
    [ "$ALLOW_HTTPS" = "yes" ] && ports+=("$HTTPS_PORT")

    if ! mkdir -p "$(dirname "$FIREWALL_POLICY_FILE")"; then
        log ERROR "Cannot create $(dirname "$FIREWALL_POLICY_FILE")."
        return 1
    fi
    if ! {
        echo "DEFAULT_INPUT=deny"
        echo "DEFAULT_OUTPUT=allow"
        printf 'ALLOW_TCP=%s\n' "${ports[@]}"
    } > "$FIREWALL_POLICY_FILE"; then
        log ERROR "Cannot write firewall policy: $FIREWALL_POLICY_FILE"
        return 1
    fi
    report "Firewall policy created: ports $(join_by ", " "${ports[@]}") ALLOWED."
}

# N-03: disable IP forwarding and ignore ICMP echo requests.
harden_kernel_network() {
    local setting
    mkdir -p "$(dirname "$SYSCTL_FILE")"
    [ -f "$SYSCTL_FILE" ] || : > "$SYSCTL_FILE"
    for setting in "net.ipv4.ip_forward=0" "net.ipv4.icmp_echo_ignore_all=1"; do
        set_option "$SYSCTL_FILE" "${setting%%=*}" " = " "${setting#*=}"
    done
    if sysctl -p "$SYSCTL_FILE" >> "$LOG_FILE" 2>&1; then
        report "Kernel network parameters applied: IP forwarding disabled, ICMP echo ignored."
    else
        log WARN "Kernel parameters written to $SYSCTL_FILE but sysctl -p reported errors."
    fi
}

harden_network() {
    log INFO "Starting network hardening."
    create_firewall_policy
    harden_kernel_network
}
