#!/bin/bash
cidr=$1
mask=""
for i in 1 2 3 4; do
    if [ $cidr -ge 8 ]; then
        mask="${mask}255"
        cidr=$((cidr - 8))
    elif [ $cidr -gt 0 ]; then
        bits=$((256 - (1 << (8 - cidr))))
        mask="${mask}${bits}"
        cidr=0
    else
        mask="${mask}0"
    fi
    [ $i -lt 4 ] && mask="${mask}."
done
echo "$mask"
