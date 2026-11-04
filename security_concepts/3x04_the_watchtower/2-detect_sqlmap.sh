#!/bin/bash

awk '
{
    low = tolower($0)
    if (index(low, "sqlmap") == 0)
        next
    if (!match($0, /"[A-Z]+ .* HTTP\/[0-9.]+"/))
        next
    req = substr($0, RSTART + 1, RLENGTH - 2)
    method = req
    sub(/ .*/, "", method)
    path = req
    sub(/^[A-Z]+ /, "", path)
    sub(/ HTTP\/[0-9.]+$/, "", path)
    print $1 "," method "," path
}
' "$1"
