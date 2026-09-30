#!/usr/bin/env python3
"""
reporter.py - Output and reporting helpers for NetProbe.

Handles writing scan results to JSON files and printing the report
header (target + reverse DNS hostname).
"""

import json
import sys
from typing import Dict, List, Optional


def print_header(ip: str, hostname: str) -> None:
    """Print the scan report header line.

    Args:
        ip: The target IP address that was scanned.
        hostname: Reverse-DNS hostname for *ip*, or the IP itself when
                  reverse lookup failed.
    """
    if hostname != ip:
        print(f"Target: {ip} ({hostname})")
    else:
        print(f"Target: {ip}")


def save_json(results: List[Dict], output_path: str) -> None:
    """Write *results* to *output_path* as formatted JSON.

    Args:
        results: List of scan-result dicts to serialise.
        output_path: Filesystem path for the output file.
    """
    try:
        with open(output_path, "w", encoding="utf-8") as fh:
            json.dump(results, fh, indent=2)
        print(f"[+] Results saved to {output_path}")
    except OSError as exc:
        print(f"[ERROR] Could not write report to '{output_path}': {exc}")
        sys.exit(1)


def print_json(results: List[Dict]) -> None:
    """Print *results* as formatted JSON to stdout.

    Args:
        results: List of scan-result dicts to display.
    """
    print(json.dumps(results, indent=2))
