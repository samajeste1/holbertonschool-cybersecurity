#!/bin/bash
# Destination port of the TCP session carrying uid=0 / root (reverse shell)
tshark -r "$1" -Y "(tcp contains \"uid=0\" || tcp contains \"root\") && !http" -T fields -e tcp.dstport 2>/dev/null | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'
