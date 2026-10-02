#!/usr/bin/env python3
"""
intel_broker.py - IntelBroker v1.0: automated IP intelligence aggregator.

Entry point. Provides the synchronous API clients, the Nmap wrapper,
the XML parser and the TargetDossier, and orchestrates them with the
async layer from api_client.py and scanner.py. Results can be saved
as a JSON report.

Usage:
    ./intel_broker.py <target> [-o report.json] [-v]
"""

import argparse
import asyncio
import json
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import Dict, List, Optional

try:
    import requests
except ImportError:
    requests = None

# The project modules are imported defensively so that the task 1-5
# functions below stay importable even when this file is used alone.
try:
    from models import BaseDossier
except ImportError:
    BaseDossier = object

try:
    from utils import cache_get, cache_set
except ImportError:
    def cache_get(key: str) -> Optional[Dict]:
        """Fallback when utils.py is missing: cache always misses."""
        return None

    def cache_set(key: str, data: Dict) -> None:
        """Fallback when utils.py is missing: do not cache."""
        return None

BASE_URL = "http://localhost:5000"
NMAP_PORTS = "22,80"


# ---------------------------------------------------------------------------
# Synchronous API clients (Tasks 1 & 2)
# ---------------------------------------------------------------------------

def _get_json(url: str) -> Dict:
    """GET *url* and return the JSON body as a dict.

    Uses requests when installed, otherwise falls back to urllib.

    Args:
        url: Full URL to GET.

    Returns:
        The JSON payload as a dict, or {"error": ...} on failure.
    """
    if requests is not None:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                return response.json()
            return {"error": f"HTTP {response.status_code}"}
        except requests.ConnectionError:
            return {"error": "Unavailable"}
        except (requests.RequestException, ValueError) as exc:
            return {"error": str(exc)}
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        return {"error": f"HTTP {exc.code}"}
    except (urllib.error.URLError, OSError):
        return {"error": "Unavailable"}
    except ValueError as exc:
        return {"error": str(exc)}


def _query_source(source: str, ip: str) -> Dict:
    """Query http://localhost:5000/<source>/<ip>, using the cache.

    Args:
        source: API name used in the URL path (e.g. 'virustotal').
        ip: Target IP address.

    Returns:
        The JSON payload as a dict, or {"error": ...} on failure.
    """
    key = f"{source}:{ip}"
    cached = cache_get(key)
    if cached:
        return cached
    data = _get_json(f"{BASE_URL}/{source}/{ip}")
    if "error" not in data:
        cache_set(key, data)
    return data


def query_virustotal(ip: str) -> Dict:
    """Query the VirusTotal mock endpoint for *ip*.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, reputation_score, malicious.
        Returns {"error": "Unavailable"} on connection failure.
    """
    return _query_source("virustotal", ip)


def query_abuseipdb(ip: str) -> Dict:
    """Query the AbuseIPDB mock endpoint for *ip*.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, abuse_confidence_score, reports.
        Returns {"error": "Unavailable"} on connection failure.
    """
    return _query_source("abuseipdb", ip)


# ---------------------------------------------------------------------------
# Nmap wrapper and XML parser (Tasks 3 & 4)
# ---------------------------------------------------------------------------

def run_nmap(ip: str) -> str:
    """Execute nmap against *ip* and return raw XML output.

    Runs: nmap -p 22,80 <ip> -oX -

    Args:
        ip: Target IP address or hostname.

    Returns:
        Raw Nmap XML output as a string.

    Raises:
        RuntimeError: If nmap is missing or returns a non-zero exit code.
    """
    try:
        result = subprocess.run(
            ["nmap", "-p", NMAP_PORTS, ip, "-oX", "-"],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except FileNotFoundError:
        raise RuntimeError("nmap is not installed or not in PATH.")
    except subprocess.TimeoutExpired:
        raise RuntimeError("nmap timed out.")
    if result.returncode != 0:
        raise RuntimeError(
            f"nmap exited {result.returncode}: {result.stderr.strip()}"
        )
    return result.stdout


def parse_nmap_xml(xml_data: str) -> List[int]:
    """Parse Nmap XML output and return a list of open port numbers.

    Iterates over host/ports/port elements and extracts portid values
    where state/@state == 'open'.

    Args:
        xml_data: Raw Nmap XML string as returned by run_nmap.

    Returns:
        A sorted list of open port numbers as integers.
        Returns an empty list when xml_data is empty or unparseable.
    """
    if not xml_data or not xml_data.strip():
        return []
    try:
        root = ET.fromstring(xml_data)
    except ET.ParseError:
        return []
    open_ports: List[int] = []
    for port in root.findall(".//port"):
        state = port.find("state")
        if state is not None and state.get("state") == "open":
            portid = port.get("portid")
            if portid and portid.isdigit():
                open_ports.append(int(portid))
    return sorted(open_ports)


# ---------------------------------------------------------------------------
# TargetDossier (Task 5)
# ---------------------------------------------------------------------------

class TargetDossier(BaseDossier):
    """Aggregated intelligence record for a single target IP or hostname.

    Attributes:
        ip: The target IP address or hostname.
        timestamp: ISO-8601 string recording when the dossier was created.
        vt_data: VirusTotal response dict.
        abuse_data: AbuseIPDB response dict.
        nmap_ports: List of open port numbers found by Nmap.
        shodan_data: Shodan response dict, or None if not queried.
        nmap_raw: Raw Nmap XML output string.
    """

    def __init__(
        self,
        ip: str = "",
        vt_data: Optional[Dict] = None,
        abuse_data: Optional[Dict] = None,
        nmap_ports: Optional[List[int]] = None,
        shodan_data: Optional[Dict] = None,
    ) -> None:
        """Initialise a dossier for *ip*, optionally pre-populated.

        Args:
            ip: Target IP address or hostname.
            vt_data: VirusTotal response dict.
            abuse_data: AbuseIPDB response dict.
            nmap_ports: List of open port numbers.
            shodan_data: Shodan response dict.
        """
        self.ip: str = ip
        self.timestamp: str = datetime.utcnow().isoformat() + "Z"
        self.vt_data: Dict = vt_data if vt_data is not None else {}
        self.abuse_data: Dict = abuse_data if abuse_data is not None else {}
        self.nmap_ports: List[int] = (
            nmap_ports if nmap_ports is not None else []
        )
        self.shodan_data: Optional[Dict] = shodan_data
        self.nmap_raw: str = ""


# ---------------------------------------------------------------------------
# Full async pipeline (Tasks 6-8)
# ---------------------------------------------------------------------------

async def run_intel(ip: str, verbose: bool = False) -> TargetDossier:
    """Run the full IntelBroker pipeline for *ip* asynchronously.

    Launches Nmap and the three API queries concurrently with
    asyncio.gather, then populates and returns a TargetDossier.

    Args:
        ip: Target IP address or hostname.
        verbose: If True, print progress messages.

    Returns:
        A fully populated TargetDossier instance.
    """
    from api_client import aiohttp, fetch_api
    from scanner import run_nmap_async

    dossier = TargetDossier(ip)

    if verbose:
        print(f"[+] Querying VirusTotal, Shodan, AbuseIPDB for {ip}...")

    async with aiohttp.ClientSession() as session:
        api_coro = asyncio.gather(
            fetch_api(session, f"{BASE_URL}/virustotal/{ip}"),
            fetch_api(session, f"{BASE_URL}/shodan/{ip}"),
            fetch_api(session, f"{BASE_URL}/abuseipdb/{ip}"),
        )
        (vt, shodan, abuse), nmap_xml = await asyncio.gather(
            api_coro, run_nmap_async(ip)
        )

    if verbose:
        print("[+] Nmap finished.")
        print("[+] API queries complete.")

    dossier.vt_data = vt
    dossier.shodan_data = shodan
    dossier.abuse_data = abuse
    dossier.nmap_raw = nmap_xml
    dossier.nmap_ports = parse_nmap_xml(nmap_xml)
    return dossier


# ---------------------------------------------------------------------------
# JSON report and CLI (Tasks 9 & 13)
# ---------------------------------------------------------------------------

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
        import api_client
    except ImportError as exc:
        print(f"[ERROR] Missing project module: {exc}")
        sys.exit(1)
    if api_client.aiohttp is None:
        print("[ERROR] aiohttp is not installed. Run: pip install aiohttp")
        sys.exit(1)

    try:
        dossier = asyncio.run(run_intel(args.target, verbose=args.verbose))
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
