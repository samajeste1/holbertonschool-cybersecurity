#!/bin/bash
awk '
{
    url = $7
    if (url == "" || url == "-") next
    sub(/^https?:\/\//, "", url)
    sub(/\/.*/, "", url)
    sub(/:.*/, "", url)
    if (url != "") count[url]++
}
END {
    for (domain in count) print count[domain], domain
}
' /var/log/squid/access.log | sort -nr | head -10
