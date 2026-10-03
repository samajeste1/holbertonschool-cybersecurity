# Network Services

Bash one-liners to inspect the services a host relies on: DNS resolver,
DHCP server, local name resolution and DNS records.

| Script | Usage | Output |
|---|---|---|
| `0-resolver.sh` | `./0-resolver.sh` | First DNS resolver from `/etc/resolv.conf` |
| `1-dhcp.sh` | `./1-dhcp.sh` | IP of the DHCP server that granted the lease |
| `2-hosts.sh` | `./2-hosts.sh` | Address mapped to `localhost` in `/etc/hosts` |
| `3-address.sh` | `./3-address.sh example.com` | A record |
| `4-cname.sh` | `./4-cname.sh www.example.com` | CNAME record |
| `5-mx.sh` | `./5-mx.sh example.com` | MX records |
| `6-txt.sh` | `./6-txt.sh example.com` | TXT records |
| `7-root.sh` | `./7-root.sh example.com` | Address of a root server found with `dig +trace` |
| `8-reverse.sh` | `./8-reverse.sh 8.8.8.8` | PTR record (reverse lookup) |
| `9-soa.sh` | `./9-soa.sh example.com` | Primary name server from the SOA record |
| `10-direct.sh` | `./10-direct.sh 1.1.1.1 example.com` | A record asked directly to a given server |
| `11-axfr.sh` | `./11-axfr.sh zone.tld ns.zone.tld` | Zone transfer attempt (AXFR) |

Requires `dig` (package `dnsutils` / `bind9-dnsutils`).
