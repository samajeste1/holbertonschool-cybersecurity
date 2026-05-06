#!/bin/bash
cidr=$2
# Build mask
mask=""
c=$cidr
for i in 1 2 3 4; do
    if [ $c -ge 8 ]; then
        mask="${mask}255"
        c=$((c - 8))
    elif [ $c -gt 0 ]; then
        mask="${mask}$((256 - (1 << (8 - c))))"
        c=0
    else
        mask="${mask}0"
    fi
    [ $i -lt 4 ] && mask="${mask}."
done

IFS='.' read -r i1 i2 i3 i4 <<< "$1"
IFS='.' read -r m1 m2 m3 m4 <<< "$mask"

# Network ID
n1=$((i1 & m1)); n2=$((i2 & m2)); n3=$((i3 & m3)); n4=$((i4 & m4))

# Broadcast
b1=$(( n1 | (255 & ~m1) )); b2=$(( n2 | (255 & ~m2) ))
b3=$(( n3 | (255 & ~m3) )); b4=$(( n4 | (255 & ~m4) ))

# First usable = network + 1, Last usable = broadcast - 1
first="${n1}.${n2}.${n3}.$((n4 + 1))"
last="${b1}.${b2}.${b3}.$((b4 - 1))"

echo "$first - $last"
