# Network Security: The Interceptor

Forward proxy for ACME Corp outbound web traffic. Squid filters HTTP and HTTPS (SNI peek only, no SSL bumping) on top of the nftables gateway from Perimeter Control.

## Environment

| Parameter   | Value          |
|-------------|----------------|
| VM          | Multipass      |
| Target Host | acme-gw01      |
| Username    | engineer       |
| Proxy       | 10.200.0.1:3128 |
| VPN clients | 10.200.0.0/24  |

## Tools

- **Proxy:** squid
- **Testing:** curl
- **Logging:** tail, grep, awk
- **Firewall:** nftables

## Files

| File | Description |
|------|-------------|
| `0-setup.sh` | Install Squid, enable it at boot, back up `squid.conf` |
| `squid.conf` | Minimal forward proxy, blacklist, extension filter, SNI peek, access log |
| `blocked_domains.txt` | Destination domains denied by the `blocked` ACL |
| `2-firewall.sh` | Accept TCP 3128/3129 from the VPN subnet |
| `3-test.sh` | HTTP fetch of example.com through the proxy (expect 200) |
| `5-test-blocked.sh` | HTTP fetch of a blacklisted domain (expect 403) |
| `7-test-extension.sh` | HTTP fetch of a `.exe` URL (expect 403) |
| `9-generate-ca.sh` | Self-signed CA and Squid SSL certificate database |
| `10-test-https.sh` | HTTPS fetch of a blacklisted domain |
| `12-blocked-requests.sh` | Timestamp, client IP and URL of every 403 |
| `13-top-sites.sh` | Ten most requested domains |
| `14-reload.sh` | Parse the configuration, then reconfigure without a restart |
| `15-force-proxy.sh` | Drop direct VPN HTTP/HTTPS and keep the proxy's own egress |

## Deploy

Run on `acme-gw01` as root, after the project 2x04 firewall is loaded. `0-setup.sh` does not start Squid.

```bash
sudo bash 0-setup.sh
sudo cp squid.conf /etc/squid/squid.conf
sudo cp blocked_domains.txt /etc/squid/blocked_domains.txt
sudo bash 2-firewall.sh
sudo bash 9-generate-ca.sh
sudo bash 14-reload.sh
sudo systemctl start squid
```

From a VPN client (`10.200.0.2`), the test scripts call `http://10.200.0.1:3128`.

## Author

samajeste1
