#!/bin/bash
dpkg -l $1 2>/dev/null | grep -q "^ii" || apt-get install -y $1
sed -i 's/\(pam_pwquality\.so.*\)/pam_pwquality.so retry=3 minlen=12 minclass=3/' $2
