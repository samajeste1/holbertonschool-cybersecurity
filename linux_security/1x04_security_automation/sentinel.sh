#!/bin/bash

CONFIG_FILE="$(dirname "$0")/sentinel.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config file not found: $CONFIG_FILE" >&2
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "${SERVICES+x}" ] || [ -z "${FILES_TO_WATCH+x}" ]; then
    echo "Error: required variables not defined" >&2
    exit 1
fi

LOG_FILE="/var/log/sentinel.log"

log() {
    local component="$1"
    local target="$2"
    local status="$3"
    local details="$4"
    local timestamp
    timestamp=$(date -u +%FT%TZ)
    echo "{\"timestamp\": \"$timestamp\", \"component\": \"$component\", \"target\": \"$target\", \"status\": \"$status\", \"details\": \"$details\"}" >> "$LOG_FILE"
}

check_services() {
    for svc in "${SERVICES[@]}"; do
        if pgrep -f "$svc" > /dev/null 2>&1; then
            log "SERVICE" "$svc" "OK" "OK: $svc is running"
        else
            if eval "$svc" > /dev/null 2>&1; then
                log "SERVICE" "$svc" "FIXED" "FIXED: Restarted $svc"
            else
                log "SERVICE" "$svc" "ALERT" "ALERT: Failed to restart $svc"
            fi
        fi
    done
}

check_integrity() {
    for file in "${FILES_TO_WATCH[@]}"; do
        local gold="/var/backups/sentinel/$(basename $file).gold"
        if [ ! -f "$gold" ]; then
            log "INTEGRITY" "$file" "ALERT" "No golden copy found"
            continue
        fi
        local live_hash gold_hash
        live_hash=$(md5sum "$file" | awk '{print $1}')
        gold_hash=$(md5sum "$gold" | awk '{print $1}')
        if [ "$live_hash" = "$gold_hash" ]; then
            log "INTEGRITY" "$file" "OK" "OK: $file integrity verified"
        else
            cp "$gold" "$file"
            log "INTEGRITY" "$file" "FIXED" "FIXED: Restored $file"
        fi
    done
}

check_ports() {
    for port in $(ss -tlnH4 | awk '{print $4}' | awk -F: '{print $NF}'); do
        local allowed=false
        for ap in "${ALLOWED_PORTS[@]}"; do
            if [ "$port" = "$ap" ]; then
                allowed=true
                break
            fi
        done
        if [ "$allowed" = false ]; then
            local pid
            pid=$(lsof -ti TCP:"$port" -s TCP:LISTEN 2>/dev/null)
            if [ -n "$pid" ]; then
                kill -9 "$pid" 2>/dev/null
                log "PORT" "$port" "ALERT" "ALERT: Killed rogue process on port $port"
            fi
        fi
    done
}

check_services
check_integrity
check_ports
