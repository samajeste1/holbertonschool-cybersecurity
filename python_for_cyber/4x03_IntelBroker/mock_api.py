#!/usr/bin/env python3
"""
mock_api.py - Local mock server simulating VirusTotal, Shodan, AbuseIPDB.

Run in a separate terminal before using intel_broker.py:
    ./mock_api.py

Endpoints:
    GET /virustotal/<ip>
    GET /shodan/<ip>
    GET /abuseipdb/<ip>
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import random


class MockHandler(BaseHTTPRequestHandler):
    """HTTP request handler that returns fake threat-intelligence data."""

    def do_GET(self):
        """Handle GET requests and return mock JSON for each API endpoint."""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        ip = self.path.split('/')[-1]

        if "virustotal" in self.path:
            score = random.randint(0, 10)
            data = {
                "ip": ip,
                "reputation_score": score,
                "malicious": score > 5,
            }
        elif "shodan" in self.path:
            ports = [80, 443, 22, 8080]
            data = {
                "ip": ip,
                "ports": random.sample(ports, k=random.randint(1, 3)),
                "os": "Linux",
                "isp": "CloudNet",
            }
        elif "abuseipdb" in self.path:
            data = {
                "ip": ip,
                "abuse_confidence_score": random.randint(0, 100),
                "reports": random.randint(0, 50),
            }
        else:
            data = {"error": "Unknown API"}

        self.wfile.write(json.dumps(data).encode())

    def log_message(self, format, *args):
        """Suppress default request logging to keep output clean."""
        pass


if __name__ == "__main__":
    server = HTTPServer(('localhost', 5000), MockHandler)
    print("Mock API Server running on port 5000...")
    server.serve_forever()
