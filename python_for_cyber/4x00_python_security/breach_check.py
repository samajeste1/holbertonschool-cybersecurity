#!/usr/bin/env python3
"""
breach_check.py - BreachCheck v1.0: leaked-credentials auditor.

Reads a leak file (email:password per line), keeps the valid lines,
flags weak passwords against the policy in config.ini, and writes a
JSON report in which passwords are stored only as salted SHA-256
hashes.

Usage:
    ./breach_check.py --file leak.txt [--output report.json] [-v]
"""

import argparse
import configparser
import hashlib
import json
import logging
import os
import re
import sys
from typing import Dict, List

from utils import read_file as read_file_lazy

CONFIG_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "config.ini"
)
LOG_FILE = "breach_check.log"
LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"

LINE_PATTERN = re.compile(
    r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
    r":[^:]+$"
)

# Policy values. Overwritten by load_config() from config.ini at startup;
# these defaults only keep check_policy() usable when imported alone.
SALT = ""
MIN_LENGTH = 8
COMMON_PASSWORDS = {"password", "123456", "12345678", "qwerty"}


def setup_logging(verbose: bool = False) -> None:
    """Configure console (INFO) and file (DEBUG) logging.

    Args:
        verbose: If True, the console also shows DEBUG messages.
    """
    formatter = logging.Formatter(LOG_FORMAT)
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    root_logger.handlers.clear()

    console = logging.StreamHandler(sys.stderr)
    console.setLevel(logging.DEBUG if verbose else logging.INFO)
    console.setFormatter(formatter)
    root_logger.addHandler(console)

    try:
        file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    except OSError as exc:
        logging.warning("Cannot write %s (%s)", LOG_FILE, exc.strerror)
        return
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)


def load_config(path: str = CONFIG_FILE) -> None:
    """Load the [SECURITY] policy from *path* into the module settings.

    Expected keys: Salt, MinLength, CommonPasswords (comma-separated).

    Args:
        path: Path of the INI configuration file.

    Exits:
        With code 1 if the file is missing or invalid.
    """
    global SALT, MIN_LENGTH, COMMON_PASSWORDS
    if not os.path.isfile(path):
        logging.error("[ERROR] Config file missing")
        sys.exit(1)
    config = configparser.ConfigParser()
    try:
        config.read(path, encoding="utf-8")
        section = config["SECURITY"]
        SALT = section.get("Salt", "")
        MIN_LENGTH = section.getint("MinLength", fallback=8)
        common = section.get("CommonPasswords", "")
    except (configparser.Error, KeyError, ValueError) as exc:
        logging.error("[ERROR] Invalid config file %s: %s", path, exc)
        sys.exit(1)
    if common:
        COMMON_PASSWORDS = {
            word.strip().lower() for word in common.split(",")
            if word.strip()
        }
    logging.debug("Config loaded: MinLength=%d, %d common passwords",
                  MIN_LENGTH, len(COMMON_PASSWORDS))


def read_file(filename: str) -> List[str]:
    """Read *filename* and return its lines as a list of strings.

    Args:
        filename: Path of the file to read.

    Returns:
        The list of raw lines.

    Exits:
        With code 1 and an [ERROR] message on stderr if the file is
        missing or unreadable.
    """
    try:
        with open(filename, "r", encoding="utf-8", errors="replace") as fh:
            return fh.readlines()
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


def clean_data(lines: List[str]) -> List[str]:
    """Remove surrounding whitespace, empty lines and # comments.

    Args:
        lines: Raw lines, e.g. [' user@mail.com:pass ', '', '# Comment'].

    Returns:
        The cleaned lines, e.g. ['user@mail.com:pass'].
    """
    cleaned_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        cleaned_lines.append(stripped)
    return cleaned_lines


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
    return re.match(LINE_PATTERN, line) is not None


def check_policy(password: str) -> str:
    """Audit *password* against the complexity policy.

    A password is WEAK if it is shorter than MIN_LENGTH, contains only
    letters (no digit), contains only digits, or is in the common
    password list.

    Args:
        password: Cleartext password.

    Returns:
        'WEAK' or 'COMPLIANT'.
    """
    if len(password) < MIN_LENGTH:
        return "WEAK"
    if password.isalpha() or not any(char.isdigit() for char in password):
        return "WEAK"
    if password.isdigit():
        return "WEAK"
    if password.lower() in COMMON_PASSWORDS:
        return "WEAK"
    return "COMPLIANT"


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


def audit_file(filename: str) -> Dict:
    """Stream *filename* and audit every valid email:password line.

    Lines are read lazily (utils.read_file generator) so memory use
    stays flat even for huge files.

    Args:
        filename: Path of the leak file.

    Returns:
        A dict with counters and the list of weak accounts, whose
        passwords are stored only as salted SHA-256 hashes.
    """
    stats = {"total_lines": 0, "valid": 0, "invalid": 0, "weak": 0}
    weak_accounts = []
    for line_number, raw_line in enumerate(read_file_lazy(filename), 1):
        stats["total_lines"] += 1
        cleaned = clean_data([raw_line])
        if not cleaned:
            continue
        line = cleaned[0]
        logging.debug("Starting regex check on line %d...", line_number)
        if not validate_line(line):
            stats["invalid"] += 1
            logging.debug("Line %d skipped: invalid format", line_number)
            continue
        stats["valid"] += 1
        email, password = line.split(":", 1)
        if check_policy(password) == "WEAK":
            stats["weak"] += 1
            weak_accounts.append({
                "email": email,
                "password_sha256": hash_password(password, SALT),
                "status": "WEAK",
            })
    return {"source": filename, "stats": stats, "weak_accounts": weak_accounts}


def save_report(report: Dict, path: str) -> None:
    """Write *report* as formatted JSON to *path*.

    Args:
        report: The audit result returned by audit_file.
        path: Output file path.

    Exits:
        With code 1 if the file cannot be written.
    """
    try:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2)
            fh.write("\n")
    except OSError as exc:
        logging.error("[ERROR] Cannot write report %s: %s",
                      path, exc.strerror)
        sys.exit(1)
    logging.info("Report generated: %s", path)


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line interface.

    Returns:
        A parser with -f/--file (required), -v/--verbose, -o/--output.
    """
    parser = argparse.ArgumentParser(
        prog="breach_check.py",
        description="BreachCheck - audit leaked email:password files "
                    "for weak passwords.",
    )
    parser.add_argument("-f", "--file", required=True,
                        help="input leak file (email:password per line)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="show debug messages on the console")
    parser.add_argument("-o", "--output",
                        help="write the JSON report to this file")
    return parser


def main() -> None:
    """Run BreachCheck: parse arguments, load config, audit, report."""
    sys.stdout.write("BreachCheck v1.0 startup...\n")
    sys.stdout.flush()
    args = build_parser().parse_args()
    setup_logging(args.verbose)
    load_config()
    try:
        logging.info("Processing file %s...", args.file)
        report = audit_file(args.file)
    except KeyboardInterrupt:
        logging.error("[ERROR] Interrupted by user")
        sys.exit(130)
    stats = report["stats"]
    logging.info("%d valid lines, %d invalid lines skipped",
                 stats["valid"], stats["invalid"])
    if stats["weak"]:
        logging.warning("[ALERT] %d weak passwords found.", stats["weak"])
    else:
        logging.info("No weak passwords found.")
    if args.output:
        save_report(report, args.output)


if __name__ == "__main__":
    main()
