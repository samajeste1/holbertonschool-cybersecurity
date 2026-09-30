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
import os
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import Dict, List, Optional, Tuple

import aiohttp
import requests


BASE_URL = "http://localhost:5000"
CACHE_FILE = "cache.json"
CACHE_TTL = 3600
_semaphore: Optional[asyncio.Semaphore] = None


# ---------------------------------------------------------------------------
# Cache helpers
# ---------------------------------------------------------------------------

def _load_cache() -> Dict:
    """Load the on-disk JSON cache, returning an empty dict on failure.

    Returns:
        A dict mapping cache keys to {data, timestamp} entries.
    """
    if not os.path.exists(CACHE_FILE):
        return {}
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}


def _save_cache(cache: Dict) -> None:
    """Persist *cache* to disk as JSON.

    Args:
        cache: The full cache dict to write.
    """
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as fh:
            json.dump(cache, fh, indent=2)
    except OSError:
        pass


def _cache_get(key: str) -> Optional[Dict]:
    """Return cached data for *key* if it exists and is still fresh.

    Args:
        key: Cache key string (e.g. 'virustotal:1.2.3.4').

    Returns:
        The cached dict, or None if missing or expired (> CACHE_TTL seconds).
    """
    cache = _load_cache()
    entry = cache.get(key)
    if entry and time.time() - entry.get("timestamp", 0) < CACHE_TTL:
        return entry.get("data")
    return None


def _cache_set(key: str, data: Dict) -> None:
    """Store *data* under *key* with the current timestamp.

    Args:
        key: Cache key string.
        data: The API response dict to cache.
    """
    cache = _load_cache()
    cache[key] = {"data": data, "timestamp": time.time()}
    _save_cache(cache)


# ---------------------------------------------------------------------------
# Synchronous API clients (Tasks 1 & 2)
# ---------------------------------------------------------------------------

def query_virustotal(ip: str) -> Dict:
    """Query the VirusTotal mock endpoint for *ip*.

    Sends a GET request to http://localhost:5000/virustotal/<ip>,
    checks for HTTP 200, and returns the JSON payload as a dict.
    Results are cached for CACHE_TTL seconds to avoid duplicate queries.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, reputation_score, malicious.
        Returns {"error": "Unavailable"} on any connection failure.
    """
    cached = _cache_get(f"virustotal:{ip}")
    if cached:
        return cached
    try:
        response = requests.get(
            f"{BASE_URL}/virustotal/{ip}", timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            _cache_set(f"virustotal:{ip}", data)
            return data
        return {"error": f"HTTP {response.status_code}"}
    except requests.ConnectionError:
        return {"error": "Unavailable"}
    except requests.RequestException as exc:
        return {"error": str(exc)}


def query_abuseipdb(ip: str) -> Dict:
    """Query the AbuseIPDB mock endpoint for *ip*.

    Sends a GET request to http://localhost:5000/abuseipdb/<ip>
    and returns the JSON payload. Results are cached.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, abuse_confidence_score, reports.
        Returns {"error": "Unavailable"} on any connection failure.
    """
    cached = _cache_get(f"abuseipdb:{ip}")
    if cached:
        return cached
    try:
        response = requests.get(
            f"{BASE_URL}/abuseipdb/{ip}", timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            _cache_set(f"abuseipdb:{ip}", data)
            return data
        return {"error": f"HTTP {response.status_code}"}
    except requests.ConnectionError:
        return {"error": "Unavailable"}
    except requests.RequestException as exc:
        return {"error": str(exc)}


# ---------------------------------------------------------------------------
# Nmap wrapper (Tasks 3 & 8)
# ---------------------------------------------------------------------------

NMAP_PORTS = "21,22,25,53,80,110,143,443,445,3306,5432,8080,8443"


def run_nmap(ip: str) -> str:
    """Execute nmap against *ip* and return raw XML output.

    Runs: nmap -p <NMAP_PORTS> <ip> -oX -

    Args:
        ip: Target IP address or hostname.

    Returns:
        Raw Nmap XML output as a string.

    Raises:
        RuntimeError: If nmap returns a non-zero exit code.
        FileNotFoundError: If nmap is not installed.
    """
    try:
        result = subprocess.run(
            ["nmap", "-p", NMAP_PORTS, ip, "-oX", "-"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"nmap exited {result.returncode}: {result.stderr.strip()}"
            )
        return result.stdout
    except FileNotFoundError:
        raise FileNotFoundError(
            "[ERROR] nmap is not installed or not in PATH."
        )


async def run_nmap_async(ip: str) -> str:
    """Execute nmap asynchronously and return raw XML output.

    Uses asyncio.create_subprocess_exec so the event loop is not
    blocked while nmap scans the target.

    Args:
        ip: Target IP address or hostname.

    Returns:
        Raw Nmap XML output as a string.

    Raises:
        RuntimeError: If nmap returns a non-zero exit code.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "nmap", "-p", NMAP_PORTS, ip, "-oX", "-",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(
                f"nmap exited {proc.returncode}: {stderr.decode().strip()}"
            )
        return stdout.decode()
    except FileNotFoundError:
        return ""


# ---------------------------------------------------------------------------
# XML parser (Task 4)
# ---------------------------------------------------------------------------

def parse_nmap_xml(xml_data: str) -> List[int]:
    """Parse Nmap XML output and return a list of open port numbers.

    Uses xml.etree.ElementTree to iterate over host/ports/port elements
    and extract portid values where state/@state == 'open'.

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
        open_ports: List[int] = []
        for port in root.findall(".//port"):
            state = port.find("state")
            if state is not None and state.get("state") == "open":
                portid = port.get("portid")
                if portid:
                    open_ports.append(int(portid))
        return sorted(open_ports)
    except ET.ParseError:
        return []


# ---------------------------------------------------------------------------
# TargetDossier (Task 5)
# ---------------------------------------------------------------------------

class TargetDossier:
    """Aggregated intelligence record for a single target IP or hostname.

    Attributes:
        ip: The target IP address or hostname.
        timestamp: ISO-8601 string recording when the dossier was created.
        vt_data: VirusTotal response dict, or None if not yet queried.
        shodan_data: Shodan response dict, or None if not yet queried.
        abuse_data: AbuseIPDB response dict, or None if not yet queried.
        nmap_ports: List of open port numbers found by Nmap.
        nmap_raw: Raw Nmap XML output string.
    """

    def __init__(self, ip: str) -> None:
        """Initialise an empty dossier for *ip*.

        Args:
            ip: Target IP address or hostname.
        """
        self.ip: str = ip
        self.timestamp: str = datetime.utcnow().isoformat() + "Z"
        self.vt_data: Optional[Dict] = None
        self.shodan_data: Optional[Dict] = None
        self.abuse_data: Optional[Dict] = None
        self.nmap_ports: List[int] = []
        self.nmap_raw: str = ""

    def to_dict(self) -> Dict:
        """Serialise the dossier to a JSON-compatible dictionary.

        Returns:
            A dict with keys: target, timestamp, intelligence.
        """
        return {
            "target": self.ip,
            "timestamp": self.timestamp,
            "intelligence": {
                "virustotal": self.vt_data or {"error": "Unavailable"},
                "shodan": self.shodan_data or {"error": "Unavailable"},
                "abuseipdb": self.abuse_data or {"error": "Unavailable"},
                "nmap": {
                    "ports": self.nmap_ports,
                    "status": "up" if self.nmap_ports else "unknown",
                },
            },
        }

    def print_summary(self) -> None:
        """Print a human-readable summary of the dossier to stdout."""
        print(f"\n{'='*50}")
        print(f"  INTEL DOSSIER: {self.ip}")
        print(f"  Generated: {self.timestamp}")
        print(f"{'='*50}")
        if self.vt_data and "error" not in self.vt_data:
            score = self.vt_data.get("reputation_score", "N/A")
            flag = self.vt_data.get("malicious", False)
            print(f"  [VirusTotal]  Score: {score}/10  Malicious: {flag}")
        else:
            print("  [VirusTotal]  Unavailable")
        if self.shodan_data and "error" not in self.shodan_data:
            ports = self.shodan_data.get("ports", [])
            isp = self.shodan_data.get("isp", "N/A")
            os_str = self.shodan_data.get("os", "N/A")
            print(
                f"  [Shodan]      Ports: {ports}"
                f"  OS: {os_str}  ISP: {isp}"
            )
        else:
            print("  [Shodan]      Unavailable")
        if self.abuse_data and "error" not in self.abuse_data:
            conf = self.abuse_data.get("abuse_confidence_score", "N/A")
            reps = self.abuse_data.get("reports", "N/A")
            print(
                f"  [AbuseIPDB]   Confidence: {conf}%  Reports: {reps}"
            )
        else:
            print("  [AbuseIPDB]   Unavailable")
        print(f"  [Nmap]        Open ports: {self.nmap_ports}")
        print(f"{'='*50}\n")


# ---------------------------------------------------------------------------
# Async API client (Tasks 6, 7, 11, 12)
# ---------------------------------------------------------------------------

def _get_semaphore() -> asyncio.Semaphore:
    """Return (or lazily create) the module-level rate-limit semaphore.

    Returns:
        An asyncio.Semaphore capped at 5 concurrent requests.
    """
    global _semaphore
    if _semaphore is None:
        _semaphore = asyncio.Semaphore(5)
    return _semaphore


async def fetch_api(
    session: aiohttp.ClientSession, url: str
) -> Dict:
    """Fetch a JSON response from *url* using an existing aiohttp session.

    Respects the module-level Semaphore (max 5 concurrent requests).
    Returns {"error": "Unavailable"} on any HTTP or network failure so
    the caller is never crashed by a single bad API response.

    Args:
        session: An active aiohttp.ClientSession.
        url: Full URL to GET.

    Returns:
        Parsed JSON dict, or {"error": "Unavailable"} on failure.
    """
    sem = _get_semaphore()
    async with sem:
        try:
            timeout = aiohttp.ClientTimeout(total=5)
            async with session.get(url, timeout=timeout) as resp:
                if resp.status == 200:
                    return await resp.json()
                return {"error": f"HTTP {resp.status}"}
        except aiohttp.ClientError:
            return {"error": "Unavailable"}
        except asyncio.TimeoutError:
            return {"error": "Timeout"}


async def gather_intel(ip: str) -> Dict:
    """Query VirusTotal, Shodan, and AbuseIPDB concurrently via asyncio.

    Uses asyncio.gather to launch all three requests simultaneously so
    total latency equals the slowest single request, not the sum.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: virustotal, shodan, abuseipdb — each a dict.
    """
    async with aiohttp.ClientSession() as session:
        vt, shodan, abuse = await asyncio.gather(
            fetch_api(session, f"{BASE_URL}/virustotal/{ip}"),
            fetch_api(session, f"{BASE_URL}/shodan/{ip}"),
            fetch_api(session, f"{BASE_URL}/abuseipdb/{ip}"),
        )
    return {"virustotal": vt, "shodan": shodan, "abuseipdb": abuse}


# ---------------------------------------------------------------------------
# Full async pipeline (Tasks 5, 8, 9, 13)
# ---------------------------------------------------------------------------

async def run_intel(
    ip: str, verbose: bool = False
) -> TargetDossier:
    """Run the full IntelBroker pipeline for *ip* asynchronously.

    Launches Nmap via asyncio.create_subprocess_exec and the three API
    queries concurrently via asyncio.gather, populates a TargetDossier,
    and returns it.

    Args:
        ip: Target IP address or hostname.
        verbose: If True, print progress messages.

    Returns:
        A fully populated TargetDossier instance.
    """
    dossier = TargetDossier(ip)

    if verbose:
        print(f"[+] Querying VirusTotal, Shodan, AbuseIPDB for {ip}...")

    async with aiohttp.ClientSession() as session:
        api_coro = asyncio.gather(
            fetch_api(session, f"{BASE_URL}/virustotal/{ip}"),
            fetch_api(session, f"{BASE_URL}/shodan/{ip}"),
            fetch_api(session, f"{BASE_URL}/abuseipdb/{ip}"),
        )
        nmap_coro = run_nmap_async(ip)
        (vt, shodan, abuse), nmap_xml = await asyncio.gather(
            api_coro, nmap_coro
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
# JSON report (Task 9)
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


# ---------------------------------------------------------------------------
# CLI (Tasks 9, 13)
# ---------------------------------------------------------------------------

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
