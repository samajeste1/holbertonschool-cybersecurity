#!/bin/bash
while IFS=: read -r user _ uid _; do
  if [ "$uid" -ge 1000 ]; then
    for grp in disk docker shadow; do
      if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then
        echo "$user:$grp"
      fi
    done
  fi
done < $1
