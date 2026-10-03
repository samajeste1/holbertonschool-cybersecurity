#!/bin/bash
# Timestamps of the first and last packets of the attacker (top SYN source)
a=$(tshark -r "$1" -Y "tcp.flags.syn == 1 && tcp.flags.ack == 0" -T fields -e ip.src 2>/dev/null | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'); tshark -r "$1" -Y "ip.addr == $a" -T fields -e frame.time 2>/dev/null | sed -n '1p;$p'
