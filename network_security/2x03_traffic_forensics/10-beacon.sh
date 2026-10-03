#!/bin/bash
a=$(tshark -r "$1" -Y "tcp.flags.syn == 1 && tcp.flags.ack == 0" -T fields -e ip.src 2>/dev/null | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}'); tshark -r "$1" -Y "ip.addr == $a && ip.addr == 10.10.10.50" -T fields -e frame.time_epoch 2>/dev/null
