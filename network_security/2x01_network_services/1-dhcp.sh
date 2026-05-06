#!/bin/bash
grep -r "DHCPACK\|dhcp-server-identifier\|server-identifier" /var/lib/dhcp/ /var/log/syslog 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
