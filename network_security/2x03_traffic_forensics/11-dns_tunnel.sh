#!/bin/bash
# DNS query names longer than 50 characters
tshark -r "$1" -Y "dns.flags.response == 0 && len(dns.qry.name) > 50" -T fields -e dns.qry.name 2>/dev/null | awk '!seen[$0]++'
