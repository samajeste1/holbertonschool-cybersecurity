#!/bin/bash
awk -v start="$(date -d '30 minutes ago' '+%b %e %H:%M:%S')" '
/sshd/ {
    ts = $1" "$2" "$3
    if (ts >= start) print
}' $1
