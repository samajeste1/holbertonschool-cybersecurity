#!/usr/bin/env python3
"""
scanner.py - Nmap wrapper for IntelBroker.

Provides synchronous and asynchronous helpers to execute Nmap and
parse the resulting XML output into a list of open port numbers.
"""

import asyncio
import subprocess
import xml.etree.ElementTree as ET
from typing import List


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
                f"nmap exited with code {result.returncode}: "
                f"{result.stderr.strip()}"
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
                f"nmap exited with code {proc.returncode}: "
                f"{stderr.decode().strip()}"
            )
        return stdout.decode()
    except FileNotFoundError:
        raise FileNotFoundError(
            "[ERROR] nmap is not installed or not in PATH."
        )


def parse_nmap_xml(xml_data: str) -> List[int]:
    """Parse Nmap XML output and return a list of open port numbers.

    Iterates over host/ports/port elements and extracts portid values
    where state/@state == 'open'.

    Args:
        xml_data: Raw Nmap XML string as returned by run_nmap.

    Returns:
        A sorted list of open port numbers as integers.
        Returns an empty list if xml_data is empty or unparseable.
    """
    if not xml_data or not xml_data.strip():
        return []
    try:
        root = ET.fromstring(xml_data)
        open_ports = []
        for port in root.findall(".//port"):
            state = port.find("state")
            if state is not None and state.get("state") == "open":
                portid = port.get("portid")
                if portid:
                    open_ports.append(int(portid))
        return sorted(open_ports)
    except ET.ParseError:
        return []
