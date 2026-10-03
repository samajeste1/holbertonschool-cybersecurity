# Network Fundamentals: Architecture & Routing

Two-line Bash tools for IP mathematics and routing analysis. Pure Bash
arithmetic (no `bc`), each script is exactly two lines long.

| Script | Usage | Example output |
|---|---|---|
| `1-dec2bin.sh` | `./1-dec2bin.sh 10` | `00001010` |
| `2-bin2dec.sh` | `./2-bin2dec.sh 11000000` | `192` |
| `3-ip2bin.sh` | `./3-ip2bin.sh 192.168.1.1` | `11000000.10101000.00000001.00000001` |
| `4-cidr2mask.sh` | `./4-cidr2mask.sh 27` | `255.255.255.224` |
| `5-network_id.sh` | `./5-network_id.sh 192.168.1.150 255.255.255.0` | `192.168.1.0` |
| `6-broadcast.sh` | `./6-broadcast.sh 10.0.0.50 255.255.255.192` | `10.0.0.63` |
| `7-host_range.sh` | `./7-host_range.sh 192.168.100.67 26` | `192.168.100.65 - 192.168.100.126` |
| `10-tunnel_ip.sh` | `./10-tunnel_ip.sh` | IP of `tun0` |
| `11-decision.sh` | `./11-decision.sh 8.8.8.8` | `LOCAL` or `REMOTE` |
| `12-gateway.sh` | `./12-gateway.sh` | default gateway IP |
| `13-hop_count.sh` | `./13-hop_count.sh google.com` | number of hops |

## Key formulas

- Network ID = IP AND Mask
- Broadcast = Network ID OR (NOT Mask)
- Usable hosts = Network ID + 1 to Broadcast - 1
- A destination is LOCAL when `ip route get` shows no `via` (direct, resolved
  with ARP), REMOTE otherwise (sent to the gateway's MAC address).
