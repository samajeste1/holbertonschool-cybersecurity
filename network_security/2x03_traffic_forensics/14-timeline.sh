#!/bin/bash
a=$(tshark -r "$1" -Y "tcp.flags.syn==1 && tcp.flags.ack==0" -T fields -e ip.src | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'); tshark -r "$1" -Y "ip.addr==$a" -T fields -e frame.time | sed -n '1p;$p'
