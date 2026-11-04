#!/bin/bash

print_lines() {
    local file="$1"
    local lines

    lines=$(wc -l < "$file" | tr -d '[:space:]')
    echo "File: ${file} - Lines: ${lines}"
}

print_lines /var/log/auth.log
print_lines /var/log/syslog
print_lines /var/log/kern.log
