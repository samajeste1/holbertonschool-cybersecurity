#!/bin/bash
tshark -r "$1" -Y "ip" -T fields -e ip.src 2>/dev/null | sort | uniq -c | sort -rn | awk '{print $2}'
