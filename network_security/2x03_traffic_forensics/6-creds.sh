#!/bin/bash
# Values of the password, pass or pwd HTTP form fields
tshark -r "$1" -Y "urlencoded-form.key in {\"password\" \"pass\" \"pwd\"}" -T fields -e urlencoded-form.key -e urlencoded-form.value 2>/dev/null | awk -F'\t' '{n = split($1, k, ","); split($2, v, ","); for (i = 1; i <= n; i++) if (k[i] ~ /^(password|pass|pwd)$/) print v[i]}'
