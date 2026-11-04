#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

cat > /etc/logrotate.d/secure_remote << 'EOF'
/var/log/secure_remote.log {
    daily
    rotate 7
    compress
    missingok
}
EOF
