#!/bin/bash
[ ! -d "$1" ] && exit 1
mkdir -p "$1/backups"
for f in "$1"/*.log; do
  [ $(stat -c%s "$f") -gt 1024 ] && gzip "$f" && mv "$f.gz" "$1/backups/" || echo "Skipping small file: $(basename $f)"
done
