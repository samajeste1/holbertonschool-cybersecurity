#!/bin/bash
# Count of TCP packets with SYN set and ACK unset
tshark -r "$1" -Y "tcp.flags.syn == 1 && tcp.flags.ack == 0" 2>/dev/null | wc -l
