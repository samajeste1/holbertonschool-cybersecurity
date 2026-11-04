#!/bin/bash

awk '
{
    if (!match($0, /"[^"]*"[[:space:]]+[0-9]{3}/))
        next
    chunk = substr($0, RSTART, RLENGTH)
    code = substr(chunk, length(chunk) - 2, 3)
    if (code ~ /^4[0-9][0-9]$/ || code == "404" || code == "403")
        count[$1]++
}
END {
    for (ip in count) {
        if (count[ip] > 5)
            print "ALERT: IP " ip " is scanning us!"
    }
}
' "$1" | sort
