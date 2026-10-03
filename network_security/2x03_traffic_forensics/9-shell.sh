#!/bin/bash
tshark -r "$1" -Y '(tcp contains "uid=0" || tcp contains "root") && !http' -T fields -e tcp.dstport | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'
