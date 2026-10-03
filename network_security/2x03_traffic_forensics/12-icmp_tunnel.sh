#!/bin/bash
# Source IP of ICMP packets larger than 100 bytes
tshark -r "$1" -Y "icmp && frame.len > 100" -T fields -e ip.src 2>/dev/null | sort -u
