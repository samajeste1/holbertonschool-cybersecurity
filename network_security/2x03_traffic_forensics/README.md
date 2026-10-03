# Network Traffic Analysis: Anatomy of a Breach

Automated tshark toolkit that reconstructs an intrusion from `incident.pcap`,
one kill-chain stage per script. Every script takes the PCAP path as `$1`
and keeps its logic on a single line.

```bash
./0-hierarchy.sh incident.pcap
```

| Script | Stage | What it extracts |
|---|---|---|
| `0-hierarchy.sh` | Triage | Protocol hierarchy (`-z io,phs`) |
| `1-talkers.sh` | Triage | Source IPs by packet count, most active first |
| `2-conversations.sh` | Triage | TCP conversations and bytes (`-z conv,tcp`) |
| `3-syn_scan.sh` | Reconnaissance | Number of SYN-only packets (half-open scan) |
| `4-enum.sh` | Reconnaissance | Number of HTTP 404 responses (directory brute force) |
| `5-user_agent.sh` | Reconnaissance | Unique User-Agents (attack tool signatures) |
| `6-creds.sh` | Initial access | Values of `password`, `pass`, `pwd` form fields |
| `7-sqli.sh` | Initial access | URIs containing `UNION`/`SELECT` (any case, URL-encoded) |
| `8-rce.sh` | Execution | Frame numbers of packets containing `/bin/sh` |
| `9-shell.sh` | Execution | Destination port of the reverse shell (`uid=0` / `root`) |
| `10-beacon.sh` | C2 | Epoch timestamps between attacker and victim `10.10.10.50` |
| `11-dns_tunnel.sh` | Exfiltration | DNS query names longer than 50 characters |
| `12-icmp_tunnel.sh` | Exfiltration | Source IPs of ICMP packets larger than 100 bytes |
| `13-carve.sh` | Exfiltration | MD5 of the file carved with `--export-objects http` |
| `14-timeline.sh` | Timeline | First and last packet timestamps of the attacker |

The attacker IP (scripts 10 and 14) is identified from the evidence itself:
the source of the most SYN-only packets, i.e. the scanning host.

## Requirements

`tshark` (Wireshark 3.x+), `coreutils`, `awk`.
