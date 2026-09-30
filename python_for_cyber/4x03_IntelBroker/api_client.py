#!/usr/bin/env python3
"""
api_client.py - Async HTTP client for IntelBroker API queries.

Wraps aiohttp to fetch JSON from the mock threat-intelligence APIs.
Includes a semaphore-based rate limiter and a simple JSON file cache.
"""

import asyncio
import json
import os
import time
from typing import Dict, Optional

import aiohttp
import requests

BASE_URL = "http://localhost:5000"
CACHE_FILE = "cache.json"
CACHE_TTL = 3600

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
        The cached dict, or None if missing or expired.
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


def query_virustotal(ip: str) -> Dict:
    """Query the VirusTotal mock endpoint synchronously.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, reputation_score, malicious.
        Returns {"error": "Unavailable"} on any failure.
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
    """Query the AbuseIPDB mock endpoint synchronously.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: ip, abuse_confidence_score, reports.
        Returns {"error": "Unavailable"} on any failure.
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


async def fetch_api(
    session: aiohttp.ClientSession, url: str
) -> Dict:
    """Fetch a JSON response from *url* using an existing aiohttp session.

    Respects the module-level semaphore (max 5 concurrent requests).

    Args:
        session: An active aiohttp.ClientSession.
        url: Full URL to GET.

    Returns:
        Parsed JSON dict, or {"error": "Unavailable"} on failure.
    """
    sem = _get_semaphore()
    async with sem:
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(
                total=5
            )) as resp:
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
    total latency is the slowest single request, not the sum of all.

    Args:
        ip: Target IP address.

    Returns:
        A dict with keys: virustotal, shodan, abuseipdb — each a dict.
    """
    async with aiohttp.ClientSession() as session:
        vt_task = fetch_api(
            session, f"{BASE_URL}/virustotal/{ip}"
        )
        shodan_task = fetch_api(
            session, f"{BASE_URL}/shodan/{ip}"
        )
        abuse_task = fetch_api(
            session, f"{BASE_URL}/abuseipdb/{ip}"
        )
        vt, shodan, abuse = await asyncio.gather(
            vt_task, shodan_task, abuse_task
        )
    return {"virustotal": vt, "shodan": shodan, "abuseipdb": abuse}
