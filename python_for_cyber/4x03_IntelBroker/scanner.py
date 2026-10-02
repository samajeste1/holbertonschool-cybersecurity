#!/usr/bin/env python3
"""
scanner.py - Async Nmap wrapper for IntelBroker.

Runs Nmap with asyncio.create_subprocess_exec so the event loop keeps
serving API requests while the scan is in progress.
"""

import asyncio

NMAP_PORTS = "22,80"


async def run_nmap_async(ip: str) -> str:
    """Execute nmap asynchronously and return raw XML output.

    Runs: nmap -p 22,80 <ip> -oX -

    Args:
        ip: Target IP address or hostname.

    Returns:
        Raw Nmap XML output as a string, or "" if nmap is not installed
        so the API results can still be reported.

    Raises:
        RuntimeError: If nmap returns a non-zero exit code.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "nmap", "-p", NMAP_PORTS, ip, "-oX", "-",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError:
        return ""
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise RuntimeError(
            f"nmap exited with code {proc.returncode}: "
            f"{stderr.decode().strip()}"
        )
    return stdout.decode()
