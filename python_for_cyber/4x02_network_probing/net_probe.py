#!/usr/bin/env python3
"""
net_probe.py - NetProbe v1.0: multithreaded TCP/UDP port scanner.

Defines all scanning primitives (check_port, get_banner, guess_service,
check_vulnerability, ping_sweep, scan_ports, scan_udp) and a CLI entry
point. Modular helpers live in scanner.py, utils.py, and reporter.py,
but every public function is also importable directly from this module.
"""

import argparse
import json
import random
import socket
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Tuple


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
    "apache 2.2.8",
    "OpenSSH 2.",
    "ProFTPD 1.3.3c",
    "Samba 3.5.0",
    "PHP/5.2.",
    "PHP/5.3.",
]


def check_port(ip: str, port: int) -> bool:
    """Check whether a single TCP port is open on the given host.

    Creates a new AF_INET/SOCK_STREAM socket, sets a 1-second timeout,
    and attempts a full TCP connect. The socket is closed via a context
    manager regardless of outcome.

    Args:
        ip: Hostname or IP address of the target.
        port: Port number to probe (1-65535).

    Returns:
        True if the port accepted the connection, False otherwise.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1.0)
            return sock.connect_ex((ip, port)) == 0
    except OSError:
        return False


def get_banner(
    ip: str, port: int, interface: Optional[str] = None
) -> str:
    """Connect to *port* on *ip* and return the service banner string.

    Sends a port-appropriate probe then reads up to MAX_BANNER_BYTES.
    For HTTP ports (80, 8080, 8443) a GET request is sent and the
    Server header value is extracted. Returns 'Unknown' when the HTTP
    response contains no Server header or when no data arrives.

    Args:
        ip: Hostname or IP address of the target.
        port: Open TCP port to grab the banner from.
        interface: Local IP to bind the socket to, or None.

    Returns:
        The banner string stripped of whitespace, or 'Unknown' when no
        data arrives, no Server header is present, or an error occurs.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(BANNER_TIMEOUT)
            if interface:
                sock.bind((interface, 0))
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
                return "Unknown"

            first_line = (
                text.splitlines()[0].strip() if text.strip() else ""
            )
            return first_line if first_line else "Unknown"

    except (socket.timeout, OSError):
        return "Unknown"


def guess_service(port: int) -> str:
    """Return a guessed service name for a well-known port number.

    Looks up *port* in KNOWN_SERVICES and appends '(Guessed)' to signal
    that this is an inference, not a confirmed banner.

    Args:
        port: TCP port number.

    Returns:
        A string like 'HTTP (Guessed)' or 'Unknown (Guessed)'.
    """
    name = KNOWN_SERVICES.get(port, "Unknown")
    return f"{name} (Guessed)"


def get_service_info(ip: str, port: int) -> str:
    """Return the service description for an open port.

    Tries banner grabbing first; falls back to guess_service when the
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
    """Check a banner string against known vulnerable version signatures.

    Args:
        banner: The service banner or version string to inspect.

    Returns:
        '[VULNERABLE]' if a known bad signature is present, '' otherwise.
    """
    for signature in VULNERABLE_SIGNATURES:
        if signature.lower() in banner.lower():
            return "[VULNERABLE]"
    return ""


def ping_sweep(subnet: str) -> List[str]:
    """Probe port 80 on every host in a /24 subnet to find live hosts.

    Iterates addresses .1 through .254 using a thread pool and returns
    IPs that responded with an open port 80.

    Args:
        subnet: The first three octets, e.g. '192.168.1'.

    Returns:
        A sorted list of IP address strings that responded on port 80.
    """
    live_hosts: List[str] = []

    def probe(octet: int) -> Optional[str]:
        ip = f"{subnet}.{octet}"
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
    delay: float = 0.0,
    interface: Optional[str] = None,
    randomise: bool = False,
) -> List[Dict]:
    """Scan a port range on *ip* using a ThreadPoolExecutor (max 50 workers).

    Attempts every port from start_port to end_port exactly once. Uses
    check_port to test each port, then get_banner on open ports. When
    randomise is True the probe order is shuffled before scanning begins.
    Flags known vulnerable versions via check_vulnerability.

    Args:
        ip: Target hostname or IP address.
        start_port: First port to scan (inclusive).
        end_port: Last port to scan (inclusive).
        delay: Seconds to sleep before each attempt (stealth mode).
        interface: Local IP to bind every outbound socket to, or None.
        randomise: If True, shuffle port order before probing.

    Returns:
        List of result dicts sorted by port:
        [{"port": int, "state": "open", "service": str,
          "vulnerability": str}, ...]
    """
    port_list = list(range(start_port, end_port + 1))
    if randomise:
        random.shuffle(port_list)
    results: List[Dict] = []

    def probe_port(port: int) -> Optional[Dict]:
        if delay > 0:
            print(f"[DEBUG] Sleeping {delay}s before next packet...")
            time.sleep(delay)
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(CONNECT_TIMEOUT)
                if interface:
                    sock.bind((interface, 0))
                if sock.connect_ex((ip, port)) != 0:
                    return None
                # port is open — grab banner on the same connection
                if port in (80, 8080, 8443):
                    sock.sendall(
                        f"GET / HTTP/1.1\r\nHost: {ip}\r\n\r\n".encode()
                    )
                else:
                    probe = BANNER_PROBES.get(port, b"")
                    if probe:
                        sock.sendall(probe)
                banner = "Unknown"
                try:
                    sock.settimeout(BANNER_TIMEOUT)
                    raw = sock.recv(MAX_BANNER_BYTES)
                    text = raw.decode("utf-8", errors="replace")
                    if port in (80, 8080, 8443):
                        for line in text.splitlines():
                            if line.lower().startswith("server:"):
                                banner = line.split(":", 1)[1].strip()
                                break
                    else:
                        first = (
                            text.splitlines()[0].strip()
                            if text.strip() else ""
                        )
                        banner = first if first else "Unknown"
                except (socket.timeout, OSError):
                    banner = "Unknown"
        except OSError:
            return None
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

    with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
        futures = [
            executor.submit(probe_port, p) for p in port_list
        ]
        for future in as_completed(futures):
            entry = future.result()
            if entry:
                results.append(entry)

    results.sort(key=lambda e: e["port"])
    return results


def scan_udp(ip: str, port: int) -> bool:
    """Probe a UDP port by sending empty bytes and waiting for a reply.

    UDP scanning is inherently unreliable: a timeout likely means
    open/filtered; an ICMP port-unreachable raises OSError (closed).

    Args:
        ip: Target hostname or IP address.
        port: UDP port number to probe.

    Returns:
        True if a datagram response arrived or the socket timed out
        (open/filtered). False on a definitive ICMP refusal.
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


def resolve_target(target: str) -> str:
    """Resolve a hostname or IP string to a dotted-quad IP address.

    Args:
        target: A hostname or IP string.

    Returns:
        The resolved IP address string.

    Raises:
        socket.gaierror: If the hostname cannot be resolved.
    """
    return socket.gethostbyname(target)


def resolve_hostname(ip: str) -> str:
    """Perform a reverse DNS lookup for *ip*.

    Args:
        ip: A dotted-quad IP address string.

    Returns:
        The resolved hostname, or the original IP string on failure.
    """
    try:
        hostname, _, _ = socket.gethostbyaddr(ip)
        return hostname
    except (socket.herror, socket.gaierror, OSError):
        return ip


def parse_port_range(port_range: str) -> Tuple[int, int]:
    """Parse a 'START-END' string into a (start, end) integer tuple.

    Args:
        port_range: A string like '1-1000' or '80-80'.

    Returns:
        A (start_port, end_port) tuple of integers.

    Raises:
        ValueError: If the format is invalid or values are out of range.
    """
    parts = port_range.split("-")
    if len(parts) != 2:
        raise ValueError(
            f"Invalid port range '{port_range}'. "
            "Expected format: START-END"
        )
    try:
        start, end = int(parts[0]), int(parts[1])
    except ValueError:
        raise ValueError(
            f"Port values must be integers, got '{port_range}'."
        )
    if not (1 <= start <= 65535) or not (1 <= end <= 65535):
        raise ValueError("Port numbers must be between 1 and 65535.")
    if start > end:
        raise ValueError(
            f"Start port {start} must be <= end port {end}."
        )
    return start, end


def build_arg_parser() -> argparse.ArgumentParser:
    """Create and return the CLI argument parser for NetProbe.

    Returns:
        A configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog="net_probe",
        description="NetProbe v1.0 - Multithreaded TCP port scanner",
    )
    parser.add_argument(
        "-t", "--target",
        default=None,
        help="Target IP address or hostname",
    )
    parser.add_argument(
        "-p", "--ports",
        default="1-1024",
        help="Port range START-END (default: 1-1024)",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Save results to a JSON file",
    )
    parser.add_argument(
        "-d", "--delay",
        type=float,
        default=0.0,
        help="Stealth delay in seconds between scan attempts",
    )
    parser.add_argument(
        "-r", "--random",
        action="store_true",
        help="Randomise port scan order",
    )
    parser.add_argument(
        "-i", "--interface",
        default=None,
        help="Local interface IP to bind outbound sockets to",
    )
    return parser


def main() -> None:
    """Entry point for NetProbe.

    Resolves the target, builds the port list, runs the threaded scan,
    prints JSON results, and optionally writes a JSON report file.
    """
    print("NetProbe v1.0 initialized...")

    parser = build_arg_parser()
    args = parser.parse_args()

    if args.target is None:
        return

    try:
        resolved_ip = resolve_target(args.target)
    except socket.gaierror as exc:
        print(f"[ERROR] Could not resolve target '{args.target}': {exc}")
        sys.exit(1)

    hostname = resolve_hostname(resolved_ip)
    if hostname != resolved_ip:
        print(f"Target: {resolved_ip} ({hostname})")
    else:
        print(f"Target: {resolved_ip}")

    try:
        start_port, end_port = parse_port_range(args.ports)
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    if args.interface:
        print(f"[INFO] Scanning from source IP: {args.interface}")

    if args.random:
        print("Scanning ports randomly...")

    print(f"[*] Scanning {resolved_ip} from {start_port} to {end_port}...")

    try:
        results = scan_ports(
            ip=resolved_ip,
            start_port=start_port,
            end_port=end_port,
            delay=args.delay,
            interface=args.interface,
            randomise=args.random,
        )
    except KeyboardInterrupt:
        print("\n[!] Scan interrupted by user.")
        sys.exit(0)

    print(json.dumps(results, indent=2))
    print(f"\n[+] Scan complete. {len(results)} open port(s) found.")

    if args.output:
        try:
            with open(args.output, "w", encoding="utf-8") as fh:
                json.dump(results, fh, indent=2)
            print(f"[+] Results saved to {args.output}")
        except OSError as exc:
            print(f"[ERROR] Could not write '{args.output}': {exc}")
            sys.exit(1)


if __name__ == "__main__":
    main()
