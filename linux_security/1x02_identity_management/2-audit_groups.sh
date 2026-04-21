#!/bin/bash
awk -F: '$3 >= 1000 {print $1}' $1 | while read user; do
  for grp in disk docker shadow; do
    if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then
      echo "$user:$grp"
    fi
  done
done
