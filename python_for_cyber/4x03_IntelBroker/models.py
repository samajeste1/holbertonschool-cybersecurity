#!/usr/bin/env python3
"""
models.py - Data model base for IntelBroker.

Defines BaseDossier, which holds the serialisation (JSON report) and
display (console summary) logic shared by TargetDossier.
"""

from typing import Dict, List, Optional


class BaseDossier:
    """Serialisation and display logic for an intelligence dossier.

    Subclasses must set: ip, timestamp, vt_data, shodan_data,
    abuse_data and nmap_ports.
    """

    ip: str
    timestamp: str
    vt_data: Dict
    shodan_data: Optional[Dict]
    abuse_data: Dict
    nmap_ports: List[int]

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
