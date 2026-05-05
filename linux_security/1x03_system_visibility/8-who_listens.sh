#!/bin/bash
ss -tlnp4 | awk -v port=":$1" '$4 ~ port {match($0, /pid=([0-9]+)/, a); print a[1]}' | xargs -I{} ps -p {} -o comm= 2>/dev/null
