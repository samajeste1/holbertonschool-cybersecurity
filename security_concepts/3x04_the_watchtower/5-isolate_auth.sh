#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

cat > /etc/rsyslog.d/60-auth.conf << 'EOF'
authpriv.info /var/log/secure_remote.log
EOF

systemctl restart rsyslog || service rsyslog restart
