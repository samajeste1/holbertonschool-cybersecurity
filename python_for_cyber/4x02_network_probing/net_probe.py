#!/usr/bin/env python3
"""
NetProbe - A multithreaded TCP port scanner with banner grabbing.

This module provides the NetProbe tool for scanning a target IP over a
specified port range, grabbing service banners, and reporting results in
structured JSON format. Uses only the standard library (socket, threading).
"""

import json
import socket
import threading
from typing import List, Dict, Optional


BANNER_PROBES: Dict[int, bytes] = {
    21: b"",
    22: b"",
    25: b"EHLO netprobe\r\n",
    80: b"HEAD / HTTP/1.0\r\n\r\n",
    443: b"HEAD / HTTP/1.0\r\n\r\n",
    3306: b"",
    5432: b"",
    6379: b"PING\r\n",
    8080: b"HEAD / HTTP/1.0\r\n\r\n",
}

CONNECT_TIMEOUT: float = 1.0
BANNER_TIMEOUT: float = 2.0
MAX_BANNER_BYTES: int = 1024
MAX_THREADS: int = 100


def grab_banner(sock: socket.socket, port: int) -> str:
    """Attempt to read a service banner from an already-connected socket.

    Sends a port-specific probe (if defined) then reads up to
    MAX_BANNER_BYTES of the response.

    Args:
        sock: A connected TCP socket.
        port: The remote port number, used to select the right probe.

    Returns:
        A stripped, printable string containing the banner text, or an
        empty string when no data is received.
    """
    try:
        probe = BANNER_PROBES.get(port)
        if probe is not None and len(probe) > 0:
            sock.sendall(probe)

        sock.settimeout(BANNER_TIMEOUT)
        raw = sock.recv(MAX_BANNER_BYTES)
        banner = raw.decode("utf-8", errors="replace").strip()
        first_line = banner.splitlines()[0] if banner else ""
        return first_line
    except (socket.timeout, OSError):
        return ""


def scan_port(
    target: str,
    port: int,
    results: List[Dict],
    lock: threading.Lock,
) -> None:
    """Probe a single TCP port on the target and record the result.

    Performs a full TCP connect. If the port is open, attempts banner
    grabbing. Appends an entry to *results* only for open ports.

    Args:
        target: Hostname or IP address to probe.
        port: Port number in the range 1–65535.
        results: Shared list where open-port dicts are appended.
        lock: Threading lock that guards writes to *results*.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(CONNECT_TIMEOUT)
            connection_result = sock.connect_ex((target, port))

            if connection_result == 0:
                banner = grab_banner(sock, port)
                entry: Dict = {
                    "port": port,
                    "state": "open",
                    "service": banner if banner else "unknown",
                }
                with lock:
                    results.append(entry)
    except OSError:
        pass


def run_scan(target: str, start_port: int, end_port: int) -> List[Dict]:
    """Scan a range of TCP ports on *target* using a thread pool.

    Spawns up to MAX_THREADS worker threads and waits for all of them to
    finish before returning.

    Args:
        target: Hostname or IP address to scan.
        start_port: First port in the range (inclusive).
        end_port: Last port in the range (inclusive).

    Returns:
        A list of dicts (sorted by port) for every open port found:
        [{"port": int, "state": "open", "service": str}, ...]
    """
    results: List[Dict] = []
    lock = threading.Lock()
    semaphore = threading.Semaphore(MAX_THREADS)
    threads: List[threading.Thread] = []

    for port in range(start_port, end_port + 1):
        semaphore.acquire()

        def worker(p: int = port) -> None:
            try:
                scan_port(target, p, results, lock)
            finally:
                semaphore.release()

        thread = threading.Thread(target=worker, daemon=True)
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

    results.sort(key=lambda entry: entry["port"])
    return results


def parse_port_range(port_range: str) -> tuple:
    """Parse a port-range string of the form 'START-END' into two integers.

    Args:
        port_range: A string like '1-1000' or '80-80'.

    Returns:
        A (start_port, end_port) tuple of integers.

    Raises:
        ValueError: If the format is invalid or the range is out of bounds.
    """
    parts = port_range.split("-")
    if len(parts) != 2:
        raise ValueError(
            f"Invalid port range '{port_range}'. Expected format: START-END"
        )
    start, end = int(parts[0]), int(parts[1])
    if not (1 <= start <= 65535) or not (1 <= end <= 65535):
        raise ValueError("Port numbers must be between 1 and 65535.")
    if start > end:
        raise ValueError(
            f"Start port {start} must be less than or equal to end port {end}."
        )
    return start, end


def resolve_target(target: str) -> str:
    """Resolve a hostname or IP string to a validated IP address string.

    Args:
        target: A hostname (e.g. 'localhost') or dotted-quad IP string.

    Returns:
        The resolved IP address as a string.

    Raises:
        socket.gaierror: If the hostname cannot be resolved.
    """
    return socket.gethostbyname(target)


def main() -> None:
    """Entry point for NetProbe.

    Prints the tool banner, accepts command-line arguments (target and
    port range), runs the scan, and outputs results as formatted JSON.
    """
    import argparse
    import sys

    print("NetProbe v1.0 initialized...")

    parser = argparse.ArgumentParser(
        prog="net_probe",
        description="NetProbe - TCP port scanner with banner grabbing",
    )
    parser.add_argument("target", nargs="?", help="Target IP or hostname")
    parser.add_argument(
        "port_range",
        nargs="?",
        default="1-1024",
        help="Port range in START-END format (default: 1-1024)",
    )

    args = parser.parse_args()

    if args.target is None:
        return

    try:
        resolved_ip = resolve_target(args.target)
    except socket.gaierror as exc:
        print(f"[ERROR] Could not resolve target '{args.target}': {exc}")
        sys.exit(1)

    try:
        start_port, end_port = parse_port_range(args.port_range)
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    print(f"[*] Scanning {resolved_ip} ports {start_port}-{end_port} ...")

    try:
        open_ports = run_scan(resolved_ip, start_port, end_port)
    except KeyboardInterrupt:
        print("\n[!] Scan interrupted by user.")
        sys.exit(0)

    print(json.dumps(open_ports, indent=2))
    print(f"\n[+] Scan complete. {len(open_ports)} open port(s) found.")


if __name__ == "__main__":
    main()
