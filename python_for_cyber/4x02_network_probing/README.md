# NetProbe

A fast, multithreaded TCP port scanner with banner grabbing, built with Python's standard `socket` and `threading` libraries.

## Description

NetProbe scans a target IP address over a specified port range, attempts to grab service banners from open ports, and outputs structured JSON results. It is designed for authorized internal network auditing.

## Features

- Full TCP connect scan (Three-Way Handshake)
- Banner grabbing with port-specific probes
- Multithreaded scanning (up to 100 concurrent threads)
- Structured JSON output
- Graceful error handling — no raw tracebacks

## Requirements

- Python 3.8+
- No third-party dependencies (standard library only)

## Setup

```bash
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install pycodestyle          # for linting only
```

## Usage

```bash
./net_probe.py <target> [port_range]
```

**Examples:**

```bash
./net_probe.py 127.0.0.1
./net_probe.py 127.0.0.1 1-1000
./net_probe.py 192.168.1.5 20-443
```

**Output:**

```json
[
  {"port": 22, "state": "open", "service": "SSH-2.0-OpenSSH_8.2p1"},
  {"port": 80, "state": "open", "service": "Apache/2.4.41 (Ubuntu)"}
]
```

## Concepts

| Concept | Explanation |
|---|---|
| TCP Three-Way Handshake | `connect_ex()` completes SYN → SYN-ACK → ACK; return code 0 means the port is open |
| Blocking vs Non-Blocking | Default sockets are blocking; `settimeout()` makes them timed-blocking to avoid hanging |
| Multithreading | A `Semaphore` caps concurrent threads so the OS is not overwhelmed |
| Banner Grabbing | After connecting, send a probe and read the first response line to identify the service |
| Timeout / Exception handling | Every socket call is wrapped in try/except; timeouts surface as `socket.timeout` |

## Limitations

- TCP connect scan only (no SYN/stealth scan without raw sockets + root)
- Scan only hosts you are authorized to probe

## Author

Holberton School — Cybersecurity Track
