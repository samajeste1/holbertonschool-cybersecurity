#!/bin/bash

auth_lines=$(wc -l < /var/log/auth.log | tr -d '[:space:]')
syslog_lines=$(wc -l < /var/log/syslog | tr -d '[:space:]')
kern_lines=$(wc -l < /var/log/kern.log | tr -d '[:space:]')

echo "File: /var/log/auth.log - Lines: ${auth_lines}"
echo "File: /var/log/syslog - Lines: ${syslog_lines}"
echo "File: /var/log/kern.log - Lines: ${kern_lines}"
