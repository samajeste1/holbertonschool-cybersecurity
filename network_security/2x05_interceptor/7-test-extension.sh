#!/bin/bash
code=$(curl -x http://10.200.0.1:3128 -o /dev/null -s -w "%{http_code}" http://example.com/test.exe)
echo "$code"
[ "$code" = "403" ]
