#!/bin/bash
# MD5 of the file carved from HTTP (largest exported object)
d=$(mktemp -d); tshark -r "$1" -q --export-objects http,"$d" > /dev/null 2>&1; md5sum "$d/$(ls -S "$d" | head -n 1)" | awk '{print $1}'; rm -rf "$d"
