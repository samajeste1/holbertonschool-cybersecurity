#!/bin/bash
bin=$1
result=0
for ((i=0; i<${#bin}; i++)); do
    result=$(( result * 2 + ${bin:$i:1} ))
done
echo "$result"
