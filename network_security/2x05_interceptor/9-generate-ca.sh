#!/bin/bash
set -euo pipefail

mkdir -p /etc/squid/ssl_cert

openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
    -keyout /etc/squid/ssl_cert/myCA.key \
    -out /etc/squid/ssl_cert/myCA.crt \
    -subj "/O=ACME Corp/CN=ACME Proxy CA"

cat /etc/squid/ssl_cert/myCA.key /etc/squid/ssl_cert/myCA.crt > /etc/squid/ssl_cert/myCA.pem
chmod 640 /etc/squid/ssl_cert/myCA.pem /etc/squid/ssl_cert/myCA.key
chown root:proxy /etc/squid/ssl_cert/myCA.pem /etc/squid/ssl_cert/myCA.key /etc/squid/ssl_cert/myCA.crt

gen=""
for candidate in \
    /usr/lib/squid/security_file_certgen \
    /usr/libexec/squid/security_file_certgen \
    /usr/lib/squid/ssl_crtd \
    /usr/libexec/squid/ssl_crtd
do
    if [ -x "$candidate" ]; then
        gen="$candidate"
        break
    fi
done

if [ -z "$gen" ]; then
    echo "Squid SSL certificate helper not found" >&2
    exit 1
fi

rm -rf /var/spool/squid/ssl_db
case "$gen" in
    *security_file_certgen)
        "$gen" -c -s /var/spool/squid/ssl_db -M 4MB
        ;;
    *)
        "$gen" -c -s /var/spool/squid/ssl_db
        ;;
esac
chown -R proxy:proxy /var/spool/squid/ssl_db
