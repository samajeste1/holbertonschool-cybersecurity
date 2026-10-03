#!/bin/bash
tshark -r "$1" -Y "dns.flags.response==0" -T fields -e dns.qry.name | awk 'length($0) > 50 && !seen[$0]++'
