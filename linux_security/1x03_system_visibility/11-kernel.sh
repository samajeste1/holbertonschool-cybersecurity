#!/bin/bash
for f in /var/log/kern.log /var/log/messages; do
    [ -f "$f" ] && grep "segfault" "$f"
done
