#!/bin/bash
# Source IPs sorted by packet count, most active first
tshark -r "$1" -Y "ip" -T fields -e ip.src 2>/dev/null | sort | uniq -c | sort -rn | awk '{print $2}'
