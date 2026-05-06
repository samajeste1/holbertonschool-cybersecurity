#!/bin/bash
dec2bin() {
    n=$1
    result=""
    for i in $(seq 7 -1 0); do
        result="${result}$(( (n >> i) & 1 ))"
    done
    echo "$result"
}
IFS='.' read -r o1 o2 o3 o4 <<< "$1"
echo "$(dec2bin $o1).$(dec2bin $o2).$(dec2bin $o3).$(dec2bin $o4)"
