#!/usr/bin/env python3
"""
intel_broker.py - IntelBroker v1.0: automated IP intelligence aggregator.

Orchestrates local Nmap scans and async threat-intelligence API queries
(VirusTotal, Shodan, AbuseIPDB) into a single JSON dossier.

Usage:
    ./intel_broker.py <target> [-o report.json] [-v]
"""

import argparse
import asyncio
import json
import sys
from datetime import datetime
from typing import Dict

from api_client import (
    gather_intel,
    query_abuseipdb,
    query_virustotal,
)
from models import TargetDossier
from scanner import parse_nmap_xml, run_nmap, run_nmap_async


def build_arg_parser() -> argparse.ArgumentParser:
    """Create and return the CLI argument parser for IntelBroker.

    Returns:
        A configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog="intel_broker",
        description="IntelBroker v1.0 - IP Intelligence Aggregator",
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="Target IP address or hostname",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Save dossier to a JSON file",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print progress messages",
    )
    return parser


def query_virustotal(ip: str) -> Dict:
    """Query the VirusTotal mock endpoint for *ip*.

    Sends a GET request to http://localhost:5000/virustotal/<ip>,
    checks for HTTP 200, and returns the JSON payload.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, reputation_score, malicious.
        Returns {"error": "Unavailable"} on any failure.
    """
    import api_client
    return api_client.query_virustotal(ip)


def query_abuseipdb(ip: str) -> Dict:
    """Query the AbuseIPDB mock endpoint for *ip*.

    Sends a GET request to http://localhost:5000/abuseipdb/<ip>
    and returns the JSON payload.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, abuse_confidence_score, reports.
        Returns {"error": "Unavailable"} on any failure.
    """
    import api_client
    return api_client.query_abuseipdb(ip)


def run_nmap(ip: str) -> str:
    """Execute nmap against *ip* and return raw XML output.

    Args:
        ip: Target IP address or hostname.

    Returns:
        Raw Nmap XML output as a string.

    Raises:
        RuntimeError: If nmap returns a non-zero exit code.
    """
    import scanner
    return scanner.run_nmap(ip)


def parse_nmap_xml(xml_data: str) -> list:
    """Parse Nmap XML output and return a list of open port numbers.

    Args:
        xml_data: Raw Nmap XML string.

    Returns:
        A sorted list of open port numbers as integers.
    """
    import scanner
    return scanner.parse_nmap_xml(xml_data)


async def fetch_api(session, url: str) -> Dict:
    """Fetch a JSON response from *url* using an aiohttp session.

    Args:
        session: An active aiohttp.ClientSession.
        url: Full URL to GET.

    Returns:
        Parsed JSON dict, or {"error": "Unavailable"} on failure.
    """
    import api_client
    return await api_client.fetch_api(session, url)


async def gather_intel(ip: str) -> Dict:
    """Query VirusTotal, Shodan, and AbuseIPDB concurrently.

    Uses asyncio.gather so all three API calls run in parallel.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: virustotal, shodan, abuseipdb.
    """
    import api_client
    return await api_client.gather_intel(ip)


async def run_intel(ip: str, verbose: bool = False) -> TargetDossier:
    """Run the full IntelBroker pipeline for *ip* asynchronously.

    Launches Nmap and the three API queries concurrently, populates
    a TargetDossier, and returns it.

    Args:
        ip: Target IP address or hostname.
        verbose: If True, print progress messages.

    Returns:
        A fully populated TargetDossier instance.
    """
    dossier = TargetDossier(ip)

    if verbose:
        print(f"[+] Querying VirusTotal, Shodan, AbuseIPDB for {ip}...")

    import api_client as _ac
    import scanner as _sc

    async with __import__('aiohttp').ClientSession() as session:
        api_task = asyncio.gather(
            _ac.fetch_api(
                session,
                f"http://localhost:5000/virustotal/{ip}",
            ),
            _ac.fetch_api(
                session,
                f"http://localhost:5000/shodan/{ip}",
            ),
            _ac.fetch_api(
                session,
                f"http://localhost:5000/abuseipdb/{ip}",
            ),
        )
        try:
            nmap_task = _sc.run_nmap_async(ip)
            vt, shodan, abuse = await api_task
            if verbose:
                print("[+] API queries complete.")
            if verbose:
                print("[+] Waiting for Nmap...")
            nmap_xml = await nmap_task
            if verbose:
                print("[+] Nmap finished.")
        except Exception:
            vt, shodan, abuse = await api_task
            nmap_xml = ""

    dossier.vt_data = vt
    dossier.shodan_data = shodan
    dossier.abuse_data = abuse
    dossier.nmap_raw = nmap_xml
    dossier.nmap_ports = _sc.parse_nmap_xml(nmap_xml)
    return dossier


def save_report(dossier: TargetDossier, path: str) -> None:
    """Write *dossier* as formatted JSON to *path*.

    Args:
        dossier: The completed TargetDossier to serialise.
        path: Filesystem path for the output JSON file.
    """
    try:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(dossier.to_dict(), fh, indent=2)
        print(f"[SUCCESS] Report generated: {path}")
    except OSError as exc:
        print(f"[ERROR] Could not write report '{path}': {exc}")
        sys.exit(1)


def main() -> None:
    """Entry point for IntelBroker.

    Parses CLI arguments, runs the async pipeline, prints the dossier
    summary, and optionally saves a JSON report.
    """
    print("IntelBroker v1.0 initialized...")

    parser = build_arg_parser()
    args = parser.parse_args()

    if args.target is None:
        parser.print_help()
        return

    try:
        dossier = asyncio.run(
            run_intel(args.target, verbose=args.verbose)
        )
    except KeyboardInterrupt:
        print("\n[!] Interrupted by user.")
        sys.exit(0)
    except Exception as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    dossier.print_summary()

    if args.output:
        save_report(dossier, args.output)


if __name__ == "__main__":
    main()
