#!/bin/bash
# System hardening functions: package updates, removal of unauthorized
# packages, installation of required tools, and the audit report.

# H-01: refresh the package index and apply pending upgrades.
update_packages() {
    if ! apt-get update -qq >> "$LOG_FILE" 2>&1; then
        log ERROR "Failed to update package repositories."
        return
    fi
    local pending
    pending=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
    if [ "$pending" -eq 0 ]; then
        log WARN "Package updates skipped (already up to date)."
    elif apt-get upgrade -y \
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
        if apt-get purge -y "$pkg" >> "$LOG_FILE" 2>&1; then
            removed+=("$pkg")
            log INFO "Removed package: $pkg"
        else
            failed=$((failed + 1))
            log ERROR "Failed to remove package: $pkg"
        fi
    done
    if [ "${#removed[@]}" -gt 0 ]; then
        report "Removed ${#removed[@]} package(s): $(join_by ", " "${removed[@]}")."
    elif [ "$failed" -eq 0 ]; then
        report "Removed: none (no unauthorized package present)."
    fi
}

# H-03: install every package listed in REQUIRED_TOOLS that is missing.
install_required_tools() {
    local installed=() failed=0 pkg
    for pkg in $REQUIRED_TOOLS; do
        is_installed "$pkg" && continue
        if apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
            installed+=("$pkg")
            log INFO "Installed package: $pkg"
        else
            failed=$((failed + 1))
            log ERROR "Failed to install package: $pkg"
        fi
    done
    if [ "${#installed[@]}" -gt 0 ]; then
        report "Installed ${#installed[@]} package(s): $(join_by ", " "${installed[@]}")."
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

# Write the audit report to REPORT_PATH: every recorded change, then
# warnings and errors, then the compliance status (FAIL if any error).
generate_report() {
    local status="PASS" summary entry level
    if [ "$ERROR_COUNT" -gt 0 ]; then
        status="FAIL"
        summary="[ERROR] Hardening procedure completed with ${ERROR_COUNT} error(s)."
    elif [ "$WARN_COUNT" -gt 0 ]; then
        summary="[INFO] Hardening procedure completed successfully (${WARN_COUNT} warning(s))."
    else
        summary="[INFO] Hardening procedure completed successfully."
    fi

    if ! {
        echo "==============================================="
        echo " HARDENING AUDIT REPORT - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==============================================="
        echo
        echo "$summary"
        for level in INFO WARN ERROR; do
            for entry in "${REPORT_ENTRIES[@]}"; do
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
