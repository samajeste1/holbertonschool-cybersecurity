#!/usr/bin/env python3
"""
utils.py - Shared helpers for IntelBroker.

Provides a simple JSON file cache with a time-to-live so repeated
queries for the same target do not hit the APIs again.
"""

import json
import os
import time
from typing import Dict, Optional

CACHE_FILE = "cache.json"
CACHE_TTL = 3600


def load_cache() -> Dict:
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


def save_cache(cache: Dict) -> None:
    """Persist *cache* to disk as JSON.

    Args:
        cache: The full cache dict to write.
    """
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as fh:
            json.dump(cache, fh, indent=2)
    except OSError:
        pass


def cache_get(key: str) -> Optional[Dict]:
    """Return cached data for *key* if it exists and is still fresh.

    Args:
        key: Cache key string (e.g. 'virustotal:1.2.3.4').

    Returns:
        The cached dict, or None if missing or expired (> CACHE_TTL seconds).
    """
    entry = load_cache().get(key)
    if entry and time.time() - entry.get("timestamp", 0) < CACHE_TTL:
        return entry.get("data")
    return None


def cache_set(key: str, data: Dict) -> None:
    """Store *data* under *key* with the current timestamp.

    Args:
        key: Cache key string.
        data: The API response dict to cache.
    """
    cache = load_cache()
    cache[key] = {"data": data, "timestamp": time.time()}
    save_cache(cache)
