#!/bin/bash

log_file="$1"

{
    echo "<!DOCTYPE html>"
    echo "<html>"
    echo "<head>"
    echo "<meta charset=\"utf-8\">"
    echo "<title>Security Report</title>"
    echo "</head>"
    echo "<body>"
    echo "<h1>Security Report</h1>"
    echo "<table>"
    echo "<tr><th>Attempts</th><th>IP Address</th></tr>"

    grep "Failed password" "$log_file" \
        | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -n 5 \
        | while read -r count ip; do
            echo "<tr><td>${count}</td><td>${ip}</td></tr>"
        done

    echo "</table>"
    echo "</body>"
    echo "</html>"
} > $2
