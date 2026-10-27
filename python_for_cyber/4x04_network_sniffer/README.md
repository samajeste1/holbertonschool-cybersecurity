# PySniffer

![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)
![Scapy](https://img.shields.io/badge/Scapy-2.5+-green.svg)

## Description

PySniffer is a lightweight network packet sniffer built with Scapy.
It captures, filters, and analyzes network traffic in real-time with
support for BPF filters, PCAP export, deep packet inspection, and
protocol-specific processing.

## Installation

```bash
python3 -m venv venv
source venv/bin/activate
pip install scapy
```

## Usage

PySniffer requires root privileges for packet capture.

```bash
# Basic capture
sudo ./sniffer.py

# Capture on specific interface
sudo ./sniffer.py -i eth0

# Filter with BPF syntax
sudo ./sniffer.py -f "tcp port 80"
sudo ./sniffer.py -f "icmp"

# Save to PCAP file
sudo ./sniffer.py --write capture.pcap

# Verbose mode with hexdump
sudo ./sniffer.py -v

# Deep packet inspection
sudo ./sniffer.py -s "password"

# Combined
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

## Architecture

PySniffer uses a **Thread/Queue** design to decouple capture from
processing:

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

- **Thread 1 (Capture)**: Runs `sniff()`, pushes packets into Queue
- **Thread 2 (Processor)**: Pulls from Queue, dispatches to handlers

This prevents packet drops under high traffic by ensuring capture is
never blocked by console I/O or disk writes.

### Class Structure

- `PacketProcessor`: Abstract base for protocol handlers
- `TCPProcessor`: Extracts IPs, ports, and TCP flags
- `UDPProcessor`: Extracts IPs and ports
- `ICMPProcessor`: Extracts source and destination IPs
- `Sniffer`: Main engine managing capture, queue, stats
- `packet_handler()`: Standalone callback for sniff()

## Running Tests

```bash
python3 -m unittest tests -v
```

## Author

samajeste1
