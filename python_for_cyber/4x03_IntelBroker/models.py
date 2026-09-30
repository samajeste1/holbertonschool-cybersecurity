#!/usr/bin/env python3
"""
models.py - Data model for IntelBroker.

Defines TargetDossier, the central data object that aggregates
intelligence from VirusTotal, Shodan, AbuseIPDB, and Nmap.
"""

from datetime import datetime
from typing import Dict, List, Optional


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
            os_name = self.shodan_data.get("os", "N/A")
            print(f"  [Shodan]      Ports: {ports}  OS: {os_name}  ISP: {isp}")
        else:
            print("  [Shodan]      Unavailable")

        if self.abuse_data and "error" not in self.abuse_data:
            conf = self.abuse_data.get("abuse_confidence_score", "N/A")
            reps = self.abuse_data.get("reports", "N/A")
            print(f"  [AbuseIPDB]   Confidence: {conf}%  Reports: {reps}")
        else:
            print("  [AbuseIPDB]   Unavailable")

        print(f"  [Nmap]        Open ports: {self.nmap_ports}")
        print(f"{'='*50}\n")
