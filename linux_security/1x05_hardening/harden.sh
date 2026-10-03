#!/bin/bash
# harden.sh - STIG-2024 hardening entry point for Ubuntu 22.04.
# Loads the configuration and the hardening modules, runs them, then
# writes audit_report.txt in the current directory.

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/harden.cfg"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=config/harden.cfg
source "$CONFIG_FILE"

# Report is written where the script is launched from.
REPORT_PATH="$PWD/${REPORT_FILE:-audit_report.txt}"
export DEBIAN_FRONTEND=noninteractive

REPORT_ENTRIES=()
WARN_COUNT=0
ERROR_COUNT=0

# log LEVEL MESSAGE - timestamped entry in LOG_FILE, clean line on stdout.
# WARN and ERROR entries are also added to the audit report.
log() {
    local level="$1" msg="$2" ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
    echo "[$level] $msg"
    case "$level" in
        WARN)
            WARN_COUNT=$((WARN_COUNT + 1))
            REPORT_ENTRIES+=("[WARN] $msg")
            ;;
        ERROR)
            ERROR_COUNT=$((ERROR_COUNT + 1))
            REPORT_ENTRIES+=("[ERROR] $msg")
            ;;
    esac
}

# report MESSAGE - log at INFO level and add the line to the audit report.
report() {
    log INFO "$1"
    REPORT_ENTRIES+=("[INFO] $1")
}

# join_by SEPARATOR ITEM... - print the items joined by SEPARATOR.
join_by() {
    local separator="$1" result="$2"
    shift 2
    local item
    for item in "$@"; do
        result+="${separator}${item}"
    done
    echo "$result"
}

# is_installed PACKAGE - true if the package is fully installed.
is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null \
        | grep -q "install ok installed"
}

# set_option FILE KEY SEPARATOR VALUE - set "KEY<sep>VALUE" in FILE:
# replace the active line(s), else the first commented one, else append.
set_option() {
    local file="$1" key="$2" separator="$3" value="$4"
    local active="^[[:space:]]*${key}\b"
    local commented="^[[:space:]]*#[[:space:]]*${key}\b"
    local line="${key}${separator}${value}"
    if [ ! -f "$file" ]; then
        log ERROR "Configuration file missing: $file"
        return 1
    fi
    if grep -qE "$active" "$file"; then
        sed -i -E "s|${active}.*|${line}|" "$file"
    elif grep -qE "$commented" "$file"; then
        sed -i -E "0,/${commented}/s|${commented}.*|${line}|" "$file"
    else
        printf '%s\n' "$line" >> "$file"
    fi
}

if ! mkdir -p "$(dirname "$LOG_FILE")" || ! touch "$LOG_FILE"; then
    echo "[ERROR] Cannot write log file: $LOG_FILE" >&2
    exit 1
fi

for module in network ssh identity system; do
    if [ ! -f "$SCRIPT_DIR/lib/$module.sh" ]; then
        echo "[ERROR] Module not found: lib/$module.sh" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/$module.sh"
done

log INFO "Hardening framework initialized"

harden_network
harden_ssh
harden_identity
harden_system
generate_report

log INFO "Hardening complete. Report saved to $REPORT_PATH"
