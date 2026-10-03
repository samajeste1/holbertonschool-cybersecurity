#!/bin/bash
tshark -r "$1" -Y 'urlencoded-form.key in {"password" "pass" "pwd"}' -T fields -e urlencoded-form.value -e urlencoded-form.key | awk -F'\t' '{n = split($2, k, ","); split($1, v, ","); for (i = 1; i <= n; i++) if (k[i] ~ /^(password|pass|pwd)$/) print v[i]}'
