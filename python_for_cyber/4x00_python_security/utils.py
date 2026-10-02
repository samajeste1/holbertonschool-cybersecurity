#!/usr/bin/env python3
"""
utils.py - Data handling helpers for BreachCheck.

Provides lazy file reading, input cleaning, format validation and
salted SHA-256 hashing. Uses the standard library only.
"""

import hashlib
import logging
import re
import sys
from typing import Iterator, List

LINE_PATTERN = re.compile(
    r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
    r":[^:]+$"
)


def read_file(filename: str) -> Iterator[str]:
    """Lazily yield the lines of *filename*, one at a time.

    Only one line is held in memory at a time, so huge leak files do
    not exhaust RAM.

    Args:
        filename: Path of the file to read.

    Yields:
        Each raw line of the file (newline included).

    Exits:
        With code 1 and an [ERROR] message on stderr if the file is
        missing, unreadable, or not valid text.
    """
    try:
        with open(filename, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                yield line
    except FileNotFoundError:
        logging.error("[ERROR] File not found: %s", filename)
        sys.exit(1)
    except PermissionError:
        logging.error("[ERROR] Permission denied: %s", filename)
        sys.exit(1)
    except IsADirectoryError:
        logging.error("[ERROR] Is a directory: %s", filename)
        sys.exit(1)
    except OSError as exc:
        logging.error("[ERROR] Could not read %s: %s", filename, exc.strerror)
        sys.exit(1)


def clean_line(line: str) -> str:
    """Strip one raw line and return it, or "" if it should be ignored.

    Args:
        line: A raw line from the input file.

    Returns:
        The stripped line, or "" for empty lines and # comments.
    """
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return ""
    return stripped


def clean_data(lines: List[str]) -> List[str]:
    """Remove surrounding whitespace, empty lines and # comments.

    Args:
        lines: Raw lines, e.g. [' user@mail.com:pass ', '', '# Comment'].

    Returns:
        The cleaned lines, e.g. ['user@mail.com:pass'].
    """
    return [cleaned for cleaned in map(clean_line, lines) if cleaned]


def validate_line(line: str) -> bool:
    """Check that *line* follows exactly the format email:password.

    Args:
        line: A cleaned line.

    Returns:
        True if the part before the single ':' looks like an email and
        a non-empty password follows, False otherwise.
    """
    if not isinstance(line, str):
        return False
    return LINE_PATTERN.match(line) is not None


def hash_password(password: str, salt: str) -> str:
    """Return the salted SHA-256 hex digest of *password*.

    Process: encode the password, append the encoded salt, hash with
    SHA-256, return the hexdigest.

    Args:
        password: Cleartext password.
        salt: Salt string appended to the password before hashing.

    Returns:
        A 64-character lowercase hexadecimal string.
    """
    return hashlib.sha256(password.encode() + salt.encode()).hexdigest()
