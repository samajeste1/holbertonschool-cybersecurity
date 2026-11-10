#!/bin/bash
# System hardening functions: package updates, removal of unauthorized
# packages, installation of required tools, and the audit report.

# H-01: refresh the package index and apply pending upgrades.
update_packages() {
    H01_OK=0
    if ! run_apt update -qq >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to update package repositories."
        H01_OK=0
        return
    fi
    H01_OK=1
    local pending
    pending=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
    if [ "$pending" -eq 0 ]; then
        log WARN "Package updates skipped (already up to date)."
    elif run_apt upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1; then
        report "${pending} packages upgraded."
    else
        log ERROR "Package upgrade failed (${pending} pending)."
    fi
}

# H-02: purge every package listed in BLOATWARE that is installed.
remove_bloatware() {
    local removed=() failed=0 pkg
    for pkg in $BLOATWARE; do
        is_installed "$pkg" || continue
        if run_apt purge -y "$pkg" >> "$LOG_FILE" 2>&1; then
            removed+=("$pkg")
            log INFO "Removed package: $pkg"
        else
            failed=$((failed + 1))
            log ERROR "Failed to remove package: $pkg"
        fi
    done
    if [ "${#removed[@]}" -gt 0 ]; then
        report "Removed: $(join_by ", " "${removed[@]}")."
    elif [ "$failed" -eq 0 ]; then
        report "Removed: none (no unauthorized package present)."
    fi
}

# H-03: install every package listed in REQUIRED_TOOLS that is missing.
install_required_tools() {
    local installed=() failed=0 pkg
    for pkg in $REQUIRED_TOOLS; do
        is_installed "$pkg" && continue
        if run_apt install -y "$pkg" >> "$LOG_FILE" 2>&1; then
            installed+=("$pkg")
            log INFO "Installed package: $pkg"
        else
            failed=$((failed + 1))
            log ERROR "Failed to install package: $pkg"
        fi
    done
    if [ "${#installed[@]}" -gt 0 ]; then
        report "Installed: $(join_by ", " "${installed[@]}")."
    elif [ "$failed" -eq 0 ]; then
        report "Installed: none (required tools already present: ${REQUIRED_TOOLS// /, })."
    fi
}

# Enable and start the services provided by REQUIRED_TOOLS.
enable_required_services() {
    local enabled=() service
    if ! command -v systemctl > /dev/null; then
        log WARN "systemctl not available: services not enabled."
        return
    fi
    for service in $REQUIRED_TOOLS; do
        is_installed "$service" || continue
        if systemctl enable --now "$service" >> "$LOG_FILE" 2>&1; then
            enabled+=("$service")
        else
            log WARN "Could not enable service: $service"
        fi
    done
    if [ "${#enabled[@]}" -gt 0 ]; then
        report "Services enabled: $(join_by ", " "${enabled[@]}")."
    fi
}

harden_system() {
    log INFO "Starting system hardening."
    update_packages
    remove_bloatware
    install_required_tools
    enable_required_services
}

# rule_ok - true when every argument, treated as a grep -E pattern,
# matches its file. Arguments are FILE PATTERN pairs.
file_has() {
    local file="$1" pattern="$2"
    [ -f "$file" ] && grep -qE "$pattern" "$file"
}

# record_rule ID DESCRIPTION - append [PASS] or [FAIL] from the
# exit status of the command that follows the description.
record_rule() {
    local rule_id="$1" description="$2"
    shift 2
    if "$@"; then
        AUDIT_LINES+=("[PASS] ${rule_id} ${description}")
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        AUDIT_LINES+=("[FAIL] ${rule_id} ${description}")
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

check_n01() {
    file_has "$FIREWALL_POLICY_FILE" '^DEFAULT_INPUT=deny$' \
        && file_has "$FIREWALL_POLICY_FILE" '^DEFAULT_OUTPUT=allow$'
}

check_n02() {
    file_has "$FIREWALL_POLICY_FILE" "^ALLOW_TCP=${SSH_PORT}$" || return 1
    [ "$ALLOW_HTTP" = "yes" ] && { file_has "$FIREWALL_POLICY_FILE" "^ALLOW_TCP=${HTTP_PORT}$" || return 1; }
    [ "$ALLOW_HTTPS" = "yes" ] && { file_has "$FIREWALL_POLICY_FILE" "^ALLOW_TCP=${HTTPS_PORT}$" || return 1; }
    return 0
}

check_n03() {
    file_has "$SYSCTL_FILE" '^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=[[:space:]]*0([[:space:]]|$)' \
        && file_has "$SYSCTL_FILE" '^[[:space:]]*net\.ipv4\.icmp_echo_ignore_all[[:space:]]*=[[:space:]]*1([[:space:]]|$)'
}

check_s01() {
    file_has "$SSH_CONFIG" '^[[:space:]]*PasswordAuthentication[[:space:]]+no([[:space:]]|$)' \
        && file_has "$SSH_CONFIG" '^[[:space:]]*PubkeyAuthentication[[:space:]]+yes([[:space:]]|$)'
}

check_s02() {
    file_has "$SSH_CONFIG" '^[[:space:]]*PermitRootLogin[[:space:]]+no([[:space:]]|$)'
}

check_i01() {
    file_has "$PWQUALITY_CONF" "^[[:space:]]*minlen[[:space:]]*=[[:space:]]*${PASS_MIN_LEN}([[:space:]]|$)" \
        && file_has "$PWQUALITY_CONF" '^[[:space:]]*ucredit[[:space:]]*=[[:space:]]*-1' \
        && file_has "$PWQUALITY_CONF" '^[[:space:]]*lcredit[[:space:]]*=[[:space:]]*-1' \
        && file_has "$PWQUALITY_CONF" '^[[:space:]]*dcredit[[:space:]]*=[[:space:]]*-1' \
        && file_has "$PWQUALITY_CONF" '^[[:space:]]*ocredit[[:space:]]*=[[:space:]]*-1' \
        && file_has "$LOGIN_DEFS" "^[[:space:]]*PASS_MAX_DAYS[[:space:]]+${PASS_MAX_DAYS}([[:space:]]|$)" \
        && file_has "$LOGIN_DEFS" "^[[:space:]]*PASS_MIN_LEN[[:space:]]+${PASS_MIN_LEN}([[:space:]]|$)"
}

check_i02() {
    file_has "$FAILLOCK_CONF" "^[[:space:]]*deny[[:space:]]*=[[:space:]]*${FAIL_LOCK_ATTEMPTS}([[:space:]]|$)" \
        && file_has "$PAM_COMMON_AUTH" "pam_faillock\\.so.*deny=${FAIL_LOCK_ATTEMPTS}"
}

check_i03() {
    local username uid
    [ -f "$PASSWD_FILE" ] || return 1
    while IFS=: read -r username _ uid _; do
        [ "$uid" -gt "$USER_UID_THRESHOLD" ] && [ "$uid" -lt "$NOBODY_UID" ] || continue
        is_protected "$username" || return 1
    done < "$PASSWD_FILE"
    return 0
}

check_i04() {
    local status
    status=$(passwd -S root 2>/dev/null | awk '{ print $2; exit }')
    if [ "$status" = "L" ]; then
        return 0
    fi
    grep -qE '^root:!' /etc/shadow 2>/dev/null
}

check_h01() {
    [ "${H01_OK:-0}" -eq 1 ]
}

check_h02() {
    local pkg
    for pkg in $BLOATWARE; do
        is_installed "$pkg" && return 1
    done
    return 0
}

check_h03() {
    local pkg
    for pkg in $REQUIRED_TOOLS; do
        is_installed "$pkg" || return 1
    done
    return 0
}

# Write audit_report.txt: changes, counts, then [WARN] and [ERROR].
# COMPLIANCE STATUS is PASS when no [ERROR] was recorded.
generate_report() {
    local status="PASS" summary="[INFO] Hardening procedure completed successfully."
    local entry level

    if [ "$ERROR_COUNT" -gt 0 ]; then
        status="FAIL"
        summary="[ERROR] Hardening procedure completed with ${ERROR_COUNT} error(s)."
    elif [ "$WARN_COUNT" -gt 0 ]; then
        summary="[INFO] Hardening procedure completed successfully."
    fi

    if ! {
        echo "==============================================="
        echo " HARDENING AUDIT REPORT - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==============================================="
        echo
        echo "$summary"
        echo "[INFO] SSH configured on port ${SSH_PORT}."
        echo "[INFO] Firewall policy created: ports ${SSH_PORT}, ${HTTP_PORT}, ${HTTPS_PORT} ALLOWED."
        for level in INFO WARN ERROR; do
            for entry in "${REPORT_ENTRIES[@]}"; do
                case "$entry" in
                    "[INFO] SSH configured"*|"[INFO] Firewall policy created"*)
                        continue
                        ;;
                esac
                [[ "$entry" == "[$level]"* ]] && echo "$entry"
            done
        done
        echo
        echo "==============================================="
        echo " COMPLIANCE STATUS: $status"
        echo "==============================================="
    } > "$REPORT_PATH"; then
        log ERROR "Cannot write audit report: $REPORT_PATH"
        return 1
    fi
    log INFO "Audit report generated: $REPORT_PATH (status: $status)."
}
