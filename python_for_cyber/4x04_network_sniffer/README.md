# PySniffer

![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)
![Scapy](https://img.shields.io/badge/Scapy-2.5+-green.svg)

## Description

PySniffer is a lightweight network packet sniffer built with Scapy. It captures, filters, and analyzes network traffic in real-time with support for BPF filters, PCAP export, deep packet inspection (payload search), and protocol-specific processing.

Designed as a portable alternative to Wireshark/Tshark for environments where GUI tools are unavailable or where programmatic packet analysis is needed.

## Installation

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install scapy
```

## Usage

PySniffer requires root privileges for packet capture.

```bash
# Basic capture (all traffic, all interfaces)
sudo ./sniffer.py

# Capture on specific interface
sudo ./sniffer.py -i eth0

# Filter with BPF syntax
sudo ./sniffer.py -f "tcp port 80"
sudo ./sniffer.py -f "icmp"
sudo ./sniffer.py -f "host 192.168.1.1 and not port 22"

# Save captured packets to PCAP file
sudo ./sniffer.py --write capture.pcap

# Verbose mode (hexdump output)
sudo ./sniffer.py -v

# Deep packet inspection (search payloads)
sudo ./sniffer.py -s "password"

# Combined usage
sudo ./sniffer.py -i eth0 -f "tcp port 80" --write out.pcap -s "secret"
```

### Arguments

| Flag | Long | Description |
|------|------|-------------|
| `-i` | `--interface` | Network interface (e.g., eth0) |
| `-f` | `--filter` | BPF filter string |
| | `--write` | Save packets to PCAP file |
| `-v` | `--verbose` | Show hexdump per packet |
| `-s` | `--search` | Search string in payloads |

### Output

```
[INFO] PySniffer initialized.
[TCP] 192.168.1.5:49812 -> 1.1.1.1:80 | Flags: S
[UDP] 192.168.1.5:5353 -> 8.8.8.8:53
[ICMP] 192.168.1.5 -> 1.1.1.1
[ALERT] Payload Match found!
^C
--- Capture Statistics ---
  TCP: 42
  UDP: 15
  ICMP: 3
  Total: 60
[INFO] Stopping capture...
```

## Architecture

PySniffer uses a **Thread/Queue** design to decouple capture from processing:

```
+----------------+    Queue    +--------------------+
| Capture Thread | ==========> | Processor Thread   |
| (scapy sniff)  |   packets   |                    |
|                |             | -> TCPProcessor     |
|                |             | -> UDPProcessor     |
|                |             | -> ICMPProcessor    |
|                |             | -> PcapWriter       |
|                |             | -> Payload Search   |
+----------------+             +--------------------+
```

- **Thread 1 (Capture)**: Runs Scapy `sniff()`, pushes raw packets into a `Queue`
- **Thread 2 (Processor)**: Pulls from Queue, dispatches to protocol-specific processors, writes PCAP, and handles output

This prevents packet drops under high traffic by ensuring the capture loop is never blocked by console I/O or disk writes.

### Class Structure

- `PacketProcessor`: Abstract base for protocol handlers
- `TCPProcessor`: Extracts IPs, ports, and TCP flags
- `UDPProcessor`: Extracts IPs and ports
- `ICMPProcessor`: Extracts source and destination IPs
- `Sniffer`: Main engine managing capture, queue, stats, and output

## Running Tests

```bash
python3 -m unittest tests -v
```

## Author

samajeste1
