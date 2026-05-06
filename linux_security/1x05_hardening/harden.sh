#!/bin/bash

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/harden.cfg"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config file not found: $CONFIG_FILE" >&2
    exit 1
fi

source "$CONFIG_FILE"

# Logging function
log() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

mkdir -p "$(dirname "$LOG_FILE")"
log "Hardening framework initialized"

# Load libraries
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/ssh.sh"
source "$SCRIPT_DIR/lib/identity.sh"
source "$SCRIPT_DIR/lib/system.sh"

# Run hardening modules
harden_network
harden_ssh
harden_identity
harden_system
generate_report

log "Hardening complete. Report saved to audit_report.txt"
