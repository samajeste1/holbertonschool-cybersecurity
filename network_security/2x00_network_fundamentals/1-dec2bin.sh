#!/bin/bash
n=$1
result=""
for i in $(seq 7 -1 0); do
    result="${result}$(( (n >> i) & 1 ))"
done
echo "$result"
