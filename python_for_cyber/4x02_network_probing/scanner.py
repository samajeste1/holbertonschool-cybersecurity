#!/usr/bin/env python3
"""
scanner.py - Core socket-level scanning logic for NetProbe.

Implements TCP port checking, banner grabbing, service guessing,
vulnerability flagging, ping sweep, UDP scanning, and the threaded
port scanner that ties them all together.
"""

import socket
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional

from utils import stealth_sleep


CONNECT_TIMEOUT: float = 1.0
BANNER_TIMEOUT: float = 2.0
MAX_BANNER_BYTES: int = 1024
MAX_THREADS: int = 50

BANNER_PROBES: Dict[int, bytes] = {
    21: b"",
    22: b"",
    25: b"EHLO netprobe\r\n",
    80: b"HEAD / HTTP/1.0\r\n\r\n",
    110: b"",
    143: b"",
    443: b"HEAD / HTTP/1.0\r\n\r\n",
    3306: b"",
    5432: b"",
    6379: b"PING\r\n",
    8080: b"HEAD / HTTP/1.0\r\n\r\n",
}

KNOWN_SERVICES: Dict[int, str] = {
    21: "FTP",
    22: "SSH",
    23: "Telnet",
    25: "SMTP",
    53: "DNS",
    80: "HTTP",
    110: "POP3",
    143: "IMAP",
    443: "HTTPS",
    445: "SMB",
    3306: "MySQL",
    5432: "PostgreSQL",
    6379: "Redis",
    8080: "HTTP-Alt",
    8443: "HTTPS-Alt",
}

VULNERABLE_SIGNATURES: List[str] = [
    "vsftpd 2.3.4",
    "Apache/2.2.8",
    "OpenSSH 2.",
    "ProFTPD 1.3.3c",
    "Samba 3.5.0",
    "PHP/5.2.",
    "PHP/5.3.",
]


def check_port(ip: str, port: int) -> bool:
    """Check whether a single TCP port is open on the given host.

    Creates a new socket, sets a 1-second timeout, and attempts a full
    TCP connect. The socket is always closed via a context manager.

    Args:
        ip: Hostname or IP address of the target.
        port: Port number to probe (1–65535).

    Returns:
        True if the port accepted the connection, False otherwise.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1.0)
            return sock.connect_ex((ip, port)) == 0
    except OSError:
        return False


def get_banner(ip: str, port: int) -> str:
    """Connect to *port* on *ip* and return the service banner string.

    Sends a port-appropriate probe then reads up to MAX_BANNER_BYTES.
    For HTTP ports (80, 8080, 8443) a full GET request is used so the
    Server header can be extracted.

    Args:
        ip: Hostname or IP address of the target.
        port: Open TCP port to grab the banner from.

    Returns:
        The first line of the decoded response, stripped of whitespace,
        or "Unknown" if no data arrives or an error occurs.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(BANNER_TIMEOUT)
            sock.connect((ip, port))

            if port in (80, 8080, 8443):
                sock.sendall(
                    f"GET / HTTP/1.1\r\nHost: {ip}\r\n\r\n".encode()
                )
            else:
                probe = BANNER_PROBES.get(port, b"")
                if probe:
                    sock.sendall(probe)

            raw = sock.recv(MAX_BANNER_BYTES)
            if not raw:
                return "Unknown"

            text = raw.decode("utf-8", errors="replace")

            if port in (80, 8080, 8443):
                for line in text.splitlines():
                    if line.lower().startswith("server:"):
                        return line.split(":", 1)[1].strip()
                first = text.splitlines()[0].strip() if text.strip() else ""
                return first if first else "Unknown"

            first_line = text.splitlines()[0].strip() if text.strip() else ""
            return first_line if first_line else "Unknown"

    except (socket.timeout, OSError):
        return "Unknown"


def guess_service(port: int) -> str:
    """Return a guessed service name for a well-known port number.

    Args:
        port: TCP port number.

    Returns:
        A string like 'HTTP (Guessed)' or 'Unknown (Guessed)'.
    """
    name = KNOWN_SERVICES.get(port, "Unknown")
    return f"{name} (Guessed)"


def get_service_info(ip: str, port: int) -> str:
    """Return the service description for an open port.

    Tries banner grabbing first. Falls back to guess_service when the
    banner is empty or 'Unknown'.

    Args:
        ip: Hostname or IP address of the target.
        port: Open TCP port to identify.

    Returns:
        A human-readable service string.
    """
    banner = get_banner(ip, port)
    if banner and banner != "Unknown":
        return banner
    return guess_service(port)


def check_vulnerability(banner: str) -> str:
    """Check a banner string against a list of known vulnerable signatures.

    Args:
        banner: The service banner or version string to inspect.

    Returns:
        '[VULNERABLE]' if a known bad signature is found, '' otherwise.
    """
    for signature in VULNERABLE_SIGNATURES:
        if signature.lower() in banner.lower():
            return "[VULNERABLE]"
    return ""


def ping_sweep(subnet: str) -> List[str]:
    """Probe port 80 on every host in a /24 subnet to find live hosts.

    Iterates addresses .1 through .254 and returns those that have
    port 80 open. Uses a thread pool for speed.

    Args:
        subnet: The first three octets of the subnet, e.g. '192.168.1'.

    Returns:
        A sorted list of IP address strings that responded on port 80.
    """
    live_hosts: List[str] = []

    def probe(host_octet: int) -> Optional[str]:
        ip = f"{subnet}.{host_octet}"
        return ip if check_port(ip, 80) else None

    with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
        futures = {executor.submit(probe, i): i for i in range(1, 255)}
        for future in as_completed(futures):
            result = future.result()
            if result:
                live_hosts.append(result)

    live_hosts.sort(key=lambda addr: int(addr.split(".")[-1]))
    return live_hosts


def scan_ports(
    ip: str,
    start_port: int,
    end_port: int,
    ports: Optional[List[int]] = None,
    delay: float = 0.0,
    interface: Optional[str] = None,
) -> List[Dict]:
    """Scan a port range on *ip* using a ThreadPoolExecutor.

    For each open port, grabs the banner, guesses the service if the
    banner is empty, and flags known vulnerable versions.

    Args:
        ip: Target hostname or IP address.
        start_port: First port (inclusive). Ignored when *ports* is given.
        end_port: Last port (inclusive). Ignored when *ports* is given.
        ports: Explicit (possibly shuffled) list of ports to scan.
               Overrides start_port/end_port when provided.
        delay: Seconds to sleep before each scan attempt (stealth mode).
        interface: Local IP address to bind the socket to, or None.

    Returns:
        A list of result dicts sorted by port number:
        [{"port": int, "state": "open", "service": str,
          "vulnerability": str}, ...]
    """
    port_list = ports if ports is not None else list(
        range(start_port, end_port + 1)
    )
    results: List[Dict] = []

    def probe_port(port: int) -> Optional[Dict]:
        stealth_sleep(delay)
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(CONNECT_TIMEOUT)
                if interface:
                    sock.bind((interface, 0))
                if sock.connect_ex((ip, port)) != 0:
                    return None
                banner = get_banner(ip, port)
                if not banner or banner == "Unknown":
                    service = guess_service(port)
                else:
                    service = banner
                vuln = check_vulnerability(service)
                vuln_flag = "YES" if vuln else "NO"
                print(
                    f"[+] Port {port} Open: {service}"
                    + (f" {vuln}" if vuln else "")
                )
                return {
                    "port": port,
                    "state": "open",
                    "service": service,
                    "vulnerability": vuln_flag,
                }
        except OSError:
            return None

    with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
        futures = {executor.submit(probe_port, p): p for p in port_list}
        for future in as_completed(futures):
            entry = future.result()
            if entry:
                results.append(entry)

    results.sort(key=lambda e: e["port"])
    return results


def scan_udp(ip: str, port: int) -> bool:
    """Probe a UDP port by sending empty bytes and waiting for a response.

    UDP scanning is inherently unreliable: no response may mean open
    (silently filtered) or simply no reply expected.

    Args:
        ip: Target hostname or IP address.
        port: UDP port number to probe.

    Returns:
        True if a response (or ICMP unreachable) was received, indicating
        open/filtered. False on definitive refusal or timeout.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(2.0)
            sock.sendto(b"", (ip, port))
            sock.recvfrom(1024)
            return True
    except socket.timeout:
        return True
    except OSError:
        return False
