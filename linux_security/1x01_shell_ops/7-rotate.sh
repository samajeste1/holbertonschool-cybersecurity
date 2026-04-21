#!/bin/bash
[ ! -d "$1" ] && exit 1
mkdir -p "$1/backups"
for f in "$1"/*.log; do
  [ $(stat -c%s "$f") -gt 1024 ] && gzip -c "$f" > "$1/backups/$(basename $f).gz" && rm "$f" || echo "Skipping small file: $(basename $f)"
done
