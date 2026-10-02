#!/usr/bin/env python3
"""
api_client.py - Async HTTP logic for IntelBroker.

Wraps aiohttp to fetch JSON from the mock threat-intelligence APIs
concurrently, with a semaphore-based rate limiter (max 5 requests).
"""

import asyncio
from typing import Dict, Optional

try:
    import aiohttp
except ImportError:
    aiohttp = None

BASE_URL = "http://localhost:5000"

_semaphore: Optional[asyncio.Semaphore] = None


def _get_semaphore() -> asyncio.Semaphore:
    """Return (or lazily create) the module-level rate-limit semaphore.

    Returns:
        An asyncio.Semaphore capped at 5 concurrent requests.
    """
    global _semaphore
    if _semaphore is None:
        _semaphore = asyncio.Semaphore(5)
    return _semaphore


async def fetch_api(session: "aiohttp.ClientSession", url: str) -> Dict:
    """Fetch a JSON response from *url* using an existing aiohttp session.

    Respects the module-level semaphore (max 5 concurrent requests).

    Args:
        session: An active aiohttp.ClientSession.
        url: Full URL to GET.

    Returns:
        Parsed JSON dict, or {"error": ...} on failure.
    """
    async with _get_semaphore():
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

    Total latency equals the slowest single request, not the sum.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: virustotal, shodan, abuseipdb - each a dict.
    """
    async with aiohttp.ClientSession() as session:
        vt, shodan, abuse = await asyncio.gather(
            fetch_api(session, f"{BASE_URL}/virustotal/{ip}"),
            fetch_api(session, f"{BASE_URL}/shodan/{ip}"),
            fetch_api(session, f"{BASE_URL}/abuseipdb/{ip}"),
        )
    return {"virustotal": vt, "shodan": shodan, "abuseipdb": abuse}
