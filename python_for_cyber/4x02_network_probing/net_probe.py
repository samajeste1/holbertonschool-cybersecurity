#!/usr/bin/env python3
"""
net_probe.py - CLI entry point for NetProbe v1.0.

Parses arguments, orchestrates the scan via scanner.py, and delegates
output to reporter.py. All socket logic lives in scanner.py; helpers
live in utils.py.

Usage:
    ./net_probe.py -t <target> [-p <start-end>] [-o <file.json>]
                   [-d <delay>] [-r] [-i <local_ip>]
"""

import argparse
import sys

import scanner
import reporter
from utils import (
    build_port_list,
    parse_port_range,
    resolve_hostname,
    resolve_target,
)


def build_arg_parser() -> argparse.ArgumentParser:
    """Create and return the argument parser for NetProbe.

    Returns:
        A configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog="net_probe",
        description="NetProbe v1.0 - Multithreaded TCP port scanner",
    )
    parser.add_argument(
        "-t", "--target",
        required=False,
        default=None,
        help="Target IP address or hostname",
    )
    parser.add_argument(
        "-p", "--ports",
        default="1-1024",
        help="Port range in START-END format (default: 1-1024)",
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
        help="Stealth delay in seconds between each scan attempt",
    )
    parser.add_argument(
        "-r", "--random",
        action="store_true",
        help="Randomise port scan order to evade sequential detection",
    )
    parser.add_argument(
        "-i", "--interface",
        default=None,
        help="Local interface IP to bind sockets to (source IP selection)",
    )
    return parser


def main() -> None:
    """Entry point for NetProbe.

    Resolves the target, builds the port list, runs the threaded scan,
    prints results, and optionally saves a JSON report.
    """
    print("NetProbe v1.0 initialized...")

    parser = build_arg_parser()
    args = parser.parse_args()

    if args.target is None:
        return

    try:
        resolved_ip = resolve_target(args.target)
    except Exception as exc:
        print(f"[ERROR] Could not resolve target '{args.target}': {exc}")
        sys.exit(1)

    hostname = resolve_hostname(resolved_ip)
    reporter.print_header(resolved_ip, hostname)

    try:
        start_port, end_port = parse_port_range(args.ports)
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    if args.random:
        print("Scanning ports randomly...")

    if args.interface:
        print(f"[INFO] Scanning from source IP: {args.interface}")

    port_list = build_port_list(start_port, end_port, randomise=args.random)
    print(f"[*] Scanning {resolved_ip} from {start_port} to {end_port}...")

    try:
        results = scanner.scan_ports(
            ip=resolved_ip,
            start_port=start_port,
            end_port=end_port,
            ports=port_list,
            delay=args.delay,
            interface=args.interface,
        )
    except KeyboardInterrupt:
        print("\n[!] Scan interrupted by user.")
        sys.exit(0)

    reporter.print_json(results)
    print(f"\n[+] Scan complete. {len(results)} open port(s) found.")

    if args.output:
        reporter.save_json(results, args.output)


if __name__ == "__main__":
    main()
