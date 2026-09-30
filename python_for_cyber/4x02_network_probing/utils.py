#!/usr/bin/env python3
"""
utils.py - Helper utilities for NetProbe.

Provides port-range parsing, randomisation, stealth delay, and
DNS reverse-lookup helpers used across the scanner modules.
"""

import random
import socket
import time
from typing import List, Tuple


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
            f"Invalid port range '{port_range}'. Expected format: START-END"
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


def build_port_list(
    start: int, end: int, randomise: bool = False
) -> List[int]:
    """Build the ordered (or shuffled) list of ports to scan.

    Args:
        start: First port number (inclusive).
        end: Last port number (inclusive).
        randomise: If True, shuffle the list before returning.

    Returns:
        A list of port integers.
    """
    ports = list(range(start, end + 1))
    if randomise:
        random.shuffle(ports)
    return ports


def stealth_sleep(delay: float) -> None:
    """Sleep for *delay* seconds and print a debug message.

    Args:
        delay: Seconds to sleep. No-op when <= 0.
    """
    if delay > 0:
        print(f"[DEBUG] Sleeping {delay}s before next packet...")
        time.sleep(delay)


def resolve_hostname(ip: str) -> str:
    """Perform a reverse DNS lookup for *ip*.

    Args:
        ip: A dotted-quad IP address string.

    Returns:
        The resolved hostname, or the original IP string if lookup fails.
    """
    try:
        hostname, _, _ = socket.gethostbyaddr(ip)
        return hostname
    except (socket.herror, socket.gaierror, OSError):
        return ip


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
