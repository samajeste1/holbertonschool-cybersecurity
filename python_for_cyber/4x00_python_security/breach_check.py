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
import json
import logging
import os
import sys
from typing import Dict, List

from utils import clean_data, clean_line, hash_password, validate_line
from utils import read_file as stream_file

CONFIG_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "config.ini"
)
LOG_FILE = "breach_check.log"
LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"

# Policy values. Overwritten by load_config() from config.ini at startup;
# these defaults only keep check_policy() usable when imported alone.
SALT = ""
MIN_LENGTH = 8
COMMON_PASSWORDS = {"password", "123456", "12345678", "qwerty"}

logger = logging.getLogger("breach_check")

__all__ = [
    "read_file",
    "clean_data",
    "validate_line",
    "check_policy",
    "hash_password",
    "main",
]


def setup_logging(verbose: bool = False) -> None:
    """Configure console (INFO) and file (DEBUG) logging.

    Args:
        verbose: If True, the console also shows DEBUG messages.
    """
    formatter = logging.Formatter(LOG_FORMAT)
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    console = logging.StreamHandler(sys.stderr)
    console.setLevel(logging.DEBUG if verbose else logging.INFO)
    console.setFormatter(formatter)
    logger.addHandler(console)

    try:
        file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    except OSError as exc:
        logger.warning("Cannot write %s (%s)", LOG_FILE, exc.strerror)
        return
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)


def load_config(path: str = CONFIG_FILE) -> None:
    """Load the [SECURITY] policy from *path* into the module settings.

    Expected keys: salt, min_length, common_passwords (comma-separated).

    Args:
        path: Path of the INI configuration file.

    Exits:
        With code 1 if the file is missing or invalid.
    """
    global SALT, MIN_LENGTH, COMMON_PASSWORDS
    if not os.path.isfile(path):
        logger.error("[ERROR] Config file missing")
        sys.exit(1)
    parser = configparser.ConfigParser()
    try:
        parser.read(path, encoding="utf-8")
        section = parser["SECURITY"]
        SALT = section.get("salt", "")
        MIN_LENGTH = section.getint("min_length", fallback=8)
        common = section.get("common_passwords", "")
    except (configparser.Error, KeyError, ValueError) as exc:
        logger.error("[ERROR] Invalid config file %s: %s", path, exc)
        sys.exit(1)
    COMMON_PASSWORDS = {
        word.strip().lower() for word in common.split(",") if word.strip()
    }
    logger.debug("Config loaded: min_length=%d, %d common passwords",
                 MIN_LENGTH, len(COMMON_PASSWORDS))


def read_file(filename: str) -> List[str]:
    """Read *filename* and return its lines as a list of strings.

    For large files prefer utils.read_file, which yields lazily.

    Args:
        filename: Path of the file to read.

    Returns:
        The list of raw lines.

    Exits:
        With code 1 and an [ERROR] message on stderr if the file is
        missing or unreadable.
    """
    return list(stream_file(filename))


def check_policy(password: str) -> str:
    """Audit *password* against the complexity policy.

    A password is WEAK if it is shorter than MIN_LENGTH, contains no
    digit (letters only), contains only digits, or is in the common
    password list.

    Args:
        password: Cleartext password.

    Returns:
        'WEAK' or 'COMPLIANT'.
    """
    if (
        len(password) < MIN_LENGTH
        or not any(char.isdigit() for char in password)
        or password.isdigit()
        or password.lower() in COMMON_PASSWORDS
    ):
        return "WEAK"
    return "COMPLIANT"


def audit_file(filename: str) -> Dict:
    """Stream *filename* and audit every valid email:password line.

    Args:
        filename: Path of the leak file.

    Returns:
        A dict with counters and the list of weak accounts, whose
        passwords are stored only as salted SHA-256 hashes.
    """
    stats = {"total_lines": 0, "valid": 0, "invalid": 0, "weak": 0}
    weak_accounts = []
    for line_number, raw_line in enumerate(stream_file(filename), start=1):
        stats["total_lines"] += 1
        line = clean_line(raw_line)
        if not line:
            continue
        logger.debug("Starting regex check on line %d...", line_number)
        if not validate_line(line):
            stats["invalid"] += 1
            logger.debug("Line %d skipped: invalid format", line_number)
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
        logger.error("[ERROR] Cannot write report %s: %s", path, exc.strerror)
        sys.exit(1)
    logger.info("Report generated: %s", path)


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
        logger.info("Processing file %s...", args.file)
        report = audit_file(args.file)
    except KeyboardInterrupt:
        logger.error("[ERROR] Interrupted by user")
        sys.exit(130)
    stats = report["stats"]
    logger.info("%d valid lines, %d invalid lines skipped",
                stats["valid"], stats["invalid"])
    if stats["weak"]:
        logger.warning("[ALERT] %d weak passwords found.", stats["weak"])
    else:
        logger.info("No weak passwords found.")
    if args.output:
        save_report(report, args.output)


if __name__ == "__main__":
    main()
