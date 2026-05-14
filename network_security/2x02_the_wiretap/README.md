# Network Traffic Analysis: The Wiretap

## Description

This project covers network packet analysis using Wireshark and tcpdump. The investigation follows a simulated security incident at Nexus Financial, working through a provided PCAP file (`nexus_capture.pcap`) to identify an attacker, reconstruct the attack timeline, and extract indicators of compromise.

## Environment

- OS: Kali Linux / ParrotOS / Ubuntu
- Tools: Wireshark 3.x+, tcpdump, nmap

## Project Structure

| File | Description |
|------|-------------|
| `0-flag.txt` | Flag from packet at (total_packets / 1000) |
| `1-flag.txt` | TTL of packet #1337 in hex as FLAG{hex_value} |
| `2-flag.txt` | Flag from first packet of the dominant IP |
| `3-filter.txt` | Wireshark filter for 10.10.10.50 |
| `3-flag.txt` | Flag from first filtered packet |
| `4-filter.txt` | Three combined display filters |
| `4-counts.txt` | Packet counts for each filter |
| `5-flag.txt` | Flag from the hidden protocol |
| `7-filter.txt` | Filter for first HTTP handshake to 10.10.10.80 |
| `7-isn.txt` | Initial Sequence Number of first HTTP session |
| `8-filters.txt` | Four TCP flag filters |
| `8-flag.txt` | Flag from most RST-sending host |
| `9-filter.txt` | Filter for UDP traffic |
| `9-port.txt` | Most popular UDP port and service |
| `10-filter.txt` | Filter for DNS queries only |
| `10-flag.txt` | Flag from DNS TXT record |
| `11-filter.txt` | Filter for HTTP traffic |
| `11-creds.txt` | Password from HTTP POST request |
| `12-filter.txt` | Filter for TLS traffic |
| `12-sni_dom.txt` | Suspicious SNI domain |
| `14-filter.txt` | Filter for unauthorized Telnet session |
| `14-password.txt` | Password from unauthorized Telnet session |
| `15-filter.txt` | Filter for TCP stream index 1 |
| `16-answer.txt` | Count of password character packets in Telnet |
| `17-filter.txt` | Filter for FTP USER and PASS commands |
| `17-answer.txt` | FTP credentials (username:password) |
| `18-flag.txt` | Flag from recovered FTP file |
| `19-answer.txt` | Two visible items in SSH despite encryption |
| `21-capture.sh` | tcpdump capture script (50 packets) |
| `21-count.txt` | ICMP and HTTP packet counts from live capture |
| `23-filter.txt` | BPF capture filter for port 80 |
| `24-icmp_mask_discovery.sh` | nmap ICMP address mask discovery script |
| `25-arp_discovery.sh` | nmap ARP host discovery script |
| `26-connect_scan.sh` | nmap TCP connect scan script |
| `27-syn_scan.sh` | nmap SYN scan script |
| `28-udp_scan.sh` | nmap UDP scan script |
| `29-scan.sh` | nmap version detection script |
| `29-version.txt` | Service version detected on port 80 |
| `30-filter.txt` | Wireshark filter to detect SYN scans |
| `31-answer.txt` | UID from id command via Telnet |
| `33-answer.txt` | Attacker IP address |
| `34-filter.txt` | Filter for attacker reconnaissance traffic |
| `34-answer.txt` | Scan start time and open ports |
| `35-answer.txt` | Exploited service and access timestamp |
| `36-answer.txt` | Number of distinct commands executed |
| `37-flag.txt` | Flag from sensitive file accessed by attacker |
| `38-answer.txt` | Exfiltration protocol and filename |
| `39-answer.txt` | C2 domain name |
| `40-answer.txt` | Total attack duration in seconds |
| `41-answer.txt` | Attacker IP, C2 domain, and scan detection filter |

## Usage

### Wireshark Display Filters

```
# Traffic to/from specific IP
ip.addr == 10.10.10.50

# Telnet traffic
tcp.port == 23

# DNS queries only
dns.flags.response == 0

# SYN scan detection
tcp.flags.syn == 1 and tcp.flags.ack == 0
```

### tcpdump

```bash
sudo tcpdump -i eth0 -c 50 -w capture.pcap
```

## Key Findings

- **Attacker IP**: 10.10.10.99
- **Attack Vector**: Telnet (port 23) on legacy server 10.10.10.50
- **Exfiltration**: FTP
- **C2 Channel**: DNS TXT records to suspicious domain
