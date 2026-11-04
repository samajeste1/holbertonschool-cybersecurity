#!/bin/bash
curl -x http://10.200.0.1:3128 --connect-timeout 15 --max-time 20 -sS -o /dev/null -w "%{http_code}\n" https://malware.com || echo "connection refused or error"
