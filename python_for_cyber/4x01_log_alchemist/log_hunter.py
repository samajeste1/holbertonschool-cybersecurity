#!/usr/bin/env python3
"""
log_hunter.py - LogHunter: a streaming log analysis engine.

Reads Apache/Nginx access logs and syslog lines as a stream, normalizes
them into LogEntry objects, enriches them (GeoIP, bot detection, threat
intel), detects attacks (SQLi, XSS, brute force, bursts), correlates
multi-step incidents and exports the alerts as a JSON report.

Usage:
    ./log_hunter.py <file> [--report report.json] [--workers N]
"""

import argparse
import json
import multiprocessing
import re
import sys
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
from functools import lru_cache
from itertools import islice
from typing import (Any, Deque, Dict, Iterable, Iterator, List, Optional,
                    Set)
from urllib.parse import unquote_plus

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------

GEOIP_DB = {'1.2.3.4': 'US', '5.6.7.8': 'RU'}
BLACKLIST = {'10.0.0.1', '192.168.1.66'}
BOT_SIGNATURES = ('sqlmap', 'nikto', 'curl', 'python')

# ---------------------------------------------------------------------------
# Pre-compiled patterns (compiled once, used for every line)
# ---------------------------------------------------------------------------

APACHE_PATTERN = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<date>[^\]]+)\] '
    r'"(?P<method>[A-Z]+) (?P<path>.*?)(?: HTTP/\d(?:\.\d)?)?" '
    r'(?P<status>\d{3}) (?P<size>\d+|-)'
    r'(?: "(?P<referer>[^"]*)" "(?P<user_agent>[^"]*)")?'
)

SYSLOG_PATTERN = re.compile(
    r'^(?P<date>[A-Z][a-z]{2}\s+\d{1,2} \d{2}:\d{2}:\d{2}) '
    r'(?P<host>\S+) (?P<process>[^:]+): (?P<message>.*)$'
)

IP_PATTERN = re.compile(r'\b(?P<ip>(?:\d{1,3}\.){3}\d{1,3})\b')
WHITESPACE_PATTERN = re.compile(r'\s+')
# Any SQLi/XSS payload needs at least one of these characters.
PAYLOAD_CHARS_PATTERN = re.compile(r"[%'\"<>;()=:+* ]")

SQLI_SIGNATURES = [
    re.compile(r'union(?:\s|\+|/\*.*?\*/)+(?:all(?:\s|\+)+)?select',
               re.IGNORECASE),
    re.compile(r"'\s*or\s+'?\w+'?\s*=\s*'?\w+", re.IGNORECASE),
    re.compile(r"'\s*(?:--|#)", re.IGNORECASE),
    re.compile(r';\s*(?:drop|delete|insert|update)\s', re.IGNORECASE),
    re.compile(r'\b(?:sleep|benchmark)\s*\(', re.IGNORECASE),
    re.compile(r'\bselect\b.+\bfrom\b', re.IGNORECASE),
]

XSS_SIGNATURES = [
    re.compile(r'<\s*script', re.IGNORECASE),
    re.compile(r'javascript\s*:', re.IGNORECASE),
    re.compile(r'\bon(?:load|error|mouseover|click|focus)\s*=',
               re.IGNORECASE),
    re.compile(r'<\s*(?:img|svg|iframe)\b', re.IGNORECASE),
    re.compile(r'document\.cookie', re.IGNORECASE),
]

APACHE_TIME_FORMATS = ('%d/%b/%Y:%H:%M:%S %z', '%d/%b/%Y:%H:%M:%S')
SYSLOG_TIME_FORMAT = '%Y %b %d %H:%M:%S'


# ---------------------------------------------------------------------------
# Task 0 - The Stream
# ---------------------------------------------------------------------------

def read_stream(file_path: str) -> Iterator[str]:
    """Yield the lines of *file_path* one at a time (constant memory).

    Args:
        file_path: Path of the log file.

    Yields:
        Each line without its trailing newline. On error, prints an
        [ERROR] message and yields nothing.
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as fh:
            for line in fh:
                yield line.rstrip('\r\n')
    except FileNotFoundError:
        print(f'[ERROR] File not found: {file_path}')
    except PermissionError:
        print(f'[ERROR] Permission denied: {file_path}')
    except IsADirectoryError:
        print(f'[ERROR] Is a directory: {file_path}')
    except OSError as exc:
        print(f'[ERROR] Cannot read {file_path}: {exc.strerror}')


# ---------------------------------------------------------------------------
# Tasks 1 & 2 - The Regex
# ---------------------------------------------------------------------------

def parse_apache_line(line: str) -> Optional[Dict[str, str]]:
    """Parse an Apache/Nginx access log line.

    Args:
        line: A raw log line.

    Returns:
        A dict with keys ip, date, method, path, status, size (and
        referer, user_agent when present), or None if it does not match.
    """
    match = APACHE_PATTERN.search(line)
    if match is None:
        return None
    parsed = match.groupdict()
    parsed['user_agent'] = parsed.get('user_agent') or ''
    parsed['referer'] = parsed.get('referer') or ''
    return parsed


def parse_syslog_line(line: str) -> Optional[Dict[str, str]]:
    """Parse a syslog line (single-digit days with extra space included).

    Args:
        line: A raw log line.

    Returns:
        A dict with keys date, host, process, message, or None if it
        does not match.
    """
    match = SYSLOG_PATTERN.search(line)
    return match.groupdict() if match else None


# ---------------------------------------------------------------------------
# Task 3 - The Normalizer
# ---------------------------------------------------------------------------

def to_status(value: Any) -> Optional[int]:
    """Return *value* as an int HTTP status, or None if not a number."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


class LogEntry:
    """A log event normalized to a common structure.

    Common attributes: ip, timestamp, service ('http' or 'ssh'),
    message, raw_line. Apache entries also carry method, path, status
    (int) and user_agent; for syslog entries these are None.
    Enrichment and detection add country, is_bot, alert_level and
    attack_type.
    """

    def __init__(self, ip: str = '', timestamp: str = '',
                 service: str = '', message: str = '',
                 raw_line: str = '', method: Optional[str] = None,
                 path: Optional[str] = None, status: Any = None,
                 user_agent: Optional[str] = None, **extra: Any) -> None:
        """Create an entry.

        Args:
            ip: Source IP address ('' if unknown).
            timestamp: Event time as found in the log.
            service: 'http' for Apache, 'ssh' for syslog.
            message: Descriptive content of the event.
            raw_line: The original log line.
            method: HTTP method (Apache only).
            path: Requested URL path (Apache only).
            status: HTTP status code, stored as int (Apache only).
            user_agent: User-Agent string (Apache only).
            **extra: Any additional attribute (country, is_bot...).
        """
        self.ip = ip or ''
        self.timestamp = timestamp
        self.service = service
        self.message = message or ''
        self.raw_line = raw_line or ''
        self.method = method
        self.path = path
        self.status = to_status(status)
        self.user_agent = user_agent
        self.attack_type = None
        for name, value in extra.items():
            setattr(self, name, value)

    def to_dict(self) -> Dict[str, Any]:
        """Return the entry's attributes as a JSON-ready dict."""
        return {name: (value.isoformat() if isinstance(value, datetime)
                       else value)
                for name, value in vars(self).items()}


def normalize_entry(parsed_dict: Dict[str, str], log_type: str,
                    raw_line: str = '') -> LogEntry:
    """Convert a parser dict into a LogEntry.

    Args:
        parsed_dict: Output of parse_apache_line or parse_syslog_line.
        log_type: 'apache' or 'syslog'.
        raw_line: The original log line.

    Returns:
        The normalized LogEntry.
    """
    if log_type == 'apache':
        return LogEntry(
            ip=parsed_dict['ip'],
            timestamp=parsed_dict['date'],
            service='http',
            message=f"{parsed_dict['method']} {parsed_dict['path']}",
            raw_line=raw_line,
            method=parsed_dict['method'],
            path=parsed_dict['path'],
            status=parsed_dict['status'],
            user_agent=parsed_dict.get('user_agent') or '',
        )

    message = parsed_dict['message']
    ip_match = IP_PATTERN.search(message)
    return LogEntry(
        ip=ip_match.group('ip') if ip_match else '',
        timestamp=parsed_dict['date'],
        service='ssh',
        message=message,
        raw_line=raw_line,
    )


# ---------------------------------------------------------------------------
# Task 4 - The Filter
# ---------------------------------------------------------------------------

def has_status(entry: LogEntry, status_codes: Iterable[int]) -> bool:
    """Return True if *entry* has a status listed in *status_codes*."""
    status = to_status(getattr(entry, 'status', None))
    return status is not None and status in status_codes


def filter_logs(stream: Iterable[LogEntry],
                status_codes: List[int] = [404, 500]) -> Iterator[LogEntry]:
    """Yield only the entries whose status is in *status_codes*.

    Entries without a status attribute (syslog) are silently skipped.

    Args:
        stream: Iterable of LogEntry objects.
        status_codes: HTTP status codes to keep (not modified).

    Yields:
        The matching entries.
    """
    for entry in stream:
        if has_status(entry, status_codes):
            yield entry


# ---------------------------------------------------------------------------
# Tasks 5, 6, 7 - Enrichment
# ---------------------------------------------------------------------------

def enrich_ip(log_entry: LogEntry) -> LogEntry:
    """Set log_entry.country from GEOIP_DB ('UNKNOWN' if absent)."""
    log_entry.country = GEOIP_DB.get(log_entry.ip, 'UNKNOWN')
    return log_entry


def analyze_user_agent(log_entry: LogEntry) -> LogEntry:
    """Set log_entry.is_bot if a tool signature appears in the entry.

    The user_agent, message and raw_line fields are searched,
    case-insensitively, for sqlmap, nikto, curl and python.
    """
    haystack = ' '.join(str(getattr(log_entry, field, '') or '')
                        for field in ('user_agent', 'message', 'raw_line')
                        ).lower()
    log_entry.is_bot = any(sig in haystack for sig in BOT_SIGNATURES)
    return log_entry


def check_threat_intel(log_entry: LogEntry) -> LogEntry:
    """Set log_entry.alert_level to 'HIGH' for blacklisted IPs, else 'LOW'."""
    log_entry.alert_level = 'HIGH' if log_entry.ip in BLACKLIST else 'LOW'
    return log_entry


# ---------------------------------------------------------------------------
# Tasks 8 & 9 - Attack detection
# ---------------------------------------------------------------------------

def _decoded_path(log_entry: LogEntry) -> str:
    """Return the entry's path URL-decoded, or '' if it cannot hold a
    payload (no special character at all, or a syslog entry)."""
    path = getattr(log_entry, 'path', '') or ''
    if not PAYLOAD_CHARS_PATTERN.search(path):
        return ''
    try:
        return unquote_plus(path)
    except (TypeError, ValueError):
        return path


def detect_sqli(log_entry: LogEntry) -> LogEntry:
    """Set log_entry.attack_type = 'SQLi' if the path holds SQLi."""
    path = _decoded_path(log_entry)
    if path and any(sig.search(path) for sig in SQLI_SIGNATURES):
        log_entry.attack_type = 'SQLi'
    return log_entry


def detect_xss(log_entry: LogEntry) -> LogEntry:
    """Set log_entry.attack_type = 'XSS' unless SQLi was already found."""
    if getattr(log_entry, 'attack_type', None) == 'SQLi':
        return log_entry
    path = _decoded_path(log_entry)
    if path and any(sig.search(path) for sig in XSS_SIGNATURES):
        log_entry.attack_type = 'XSS'
    return log_entry


# ---------------------------------------------------------------------------
# Per-line pipeline: parse -> normalize -> enrich -> detect
# ---------------------------------------------------------------------------

def process_line(line: str) -> Optional[LogEntry]:
    """Run the full per-line pipeline on one raw line.

    Returns:
        The processed LogEntry, or None if no parser matches.
    """
    parsed = parse_apache_line(line)
    if parsed is not None:
        entry = normalize_entry(parsed, 'apache', line)
    else:
        parsed = parse_syslog_line(line)
        if parsed is None:
            return None
        entry = normalize_entry(parsed, 'syslog', line)
    enrich_ip(entry)
    analyze_user_agent(entry)
    check_threat_intel(entry)
    detect_sqli(entry)
    detect_xss(entry)
    return entry


# ---------------------------------------------------------------------------
# Task 10 - The Brute Force
# ---------------------------------------------------------------------------

class BruteForceDetector:
    """Count authentication failures (HTTP 401, SSH Failed password)."""

    def __init__(self, threshold: int = 5) -> None:
        """Alert when an IP has more than *threshold* failures."""
        self.threshold = threshold
        self.failures: Counter = Counter()

    def update(self, entry: LogEntry) -> None:
        """Account for one entry."""
        if not entry.ip:
            return
        if (to_status(getattr(entry, 'status', None)) == 401
                or 'Failed password' in (entry.message or '')):
            self.failures[entry.ip] += 1

    def alerts(self) -> Iterator[Dict[str, Any]]:
        """Yield one BRUTE_FORCE alert per IP above the threshold."""
        for ip, count in self.failures.most_common():
            if count <= self.threshold:
                break
            yield {'ip': ip, 'count': count, 'alert_type': 'BRUTE_FORCE'}


def detect_bruteforce(entries: Iterable[LogEntry]
                      ) -> Iterator[Dict[str, Any]]:
    """Yield BRUTE_FORCE alerts for IPs with more than 5 failures."""
    detector = BruteForceDetector()
    for entry in entries:
        detector.update(entry)
    yield from detector.alerts()


# ---------------------------------------------------------------------------
# Task 11 - The Rate Limiter
# ---------------------------------------------------------------------------

def _to_naive_utc(moment: datetime) -> datetime:
    """Convert an aware datetime to naive UTC (naive ones are kept)."""
    if moment.tzinfo is not None:
        return moment.astimezone(timezone.utc).replace(tzinfo=None)
    return moment


@lru_cache(maxsize=65536)
def parse_timestamp(timestamp: Any) -> Optional[datetime]:
    """Parse an Apache or syslog timestamp into a naive UTC datetime.

    Accepted: '11/Feb/2026:14:01:24 +0000' (Apache), 'Feb 11 14:31:24'
    (syslog, current year assumed), ISO 8601, or a datetime object.
    Results are cached because consecutive lines share the same second.

    Returns:
        The datetime, or None if the value cannot be parsed.
    """
    if isinstance(timestamp, datetime):
        return _to_naive_utc(timestamp)
    if not isinstance(timestamp, str) or not timestamp.strip():
        return None
    for time_format in APACHE_TIME_FORMATS:
        try:
            return _to_naive_utc(datetime.strptime(timestamp, time_format))
        except ValueError:
            continue
    try:
        compact = WHITESPACE_PATTERN.sub(' ', timestamp.strip())
        return datetime.strptime(f'{datetime.now().year} {compact}',
                                 SYSLOG_TIME_FORMAT)
    except ValueError:
        pass
    try:
        return _to_naive_utc(datetime.fromisoformat(timestamp.strip()))
    except ValueError:
        return None


class BurstDetector:
    """Sliding time window of requests per IP."""

    def __init__(self, window_seconds: int = 60,
                 threshold: int = 10) -> None:
        """Alert once per IP when *threshold* events fit in the window."""
        self.window_seconds = window_seconds
        self.threshold = threshold
        self.windows: Dict[str, Deque[datetime]] = defaultdict(deque)
        self.alerted: Set[str] = set()

    def update(self, entry: LogEntry) -> Optional[Dict[str, Any]]:
        """Account for one entry; return a BURST alert if one fires."""
        if not entry.ip or entry.ip in self.alerted:
            return None
        moment = parse_timestamp(entry.timestamp)
        if moment is None:
            return None
        window = self.windows[entry.ip]
        window.append(moment)
        while (window[-1] - window[0]).total_seconds() > self.window_seconds:
            window.popleft()
        if len(window) < self.threshold:
            return None
        self.alerted.add(entry.ip)
        del self.windows[entry.ip]
        return {'ip': entry.ip, 'count': self.threshold,
                'window': self.window_seconds, 'alert_type': 'BURST'}


def detect_burst(entries: Iterable[LogEntry], window_seconds: int = 60,
                 threshold: int = 10) -> Iterator[Dict[str, Any]]:
    """Yield a BURST alert per IP reaching *threshold* events in a window."""
    detector = BurstDetector(window_seconds, threshold)
    for entry in entries:
        alert = detector.update(entry)
        if alert:
            yield alert


# ---------------------------------------------------------------------------
# Task 12 - The Correlator
# ---------------------------------------------------------------------------

class EventCorrelator:
    """Track attack stages per IP: scan (404) followed by SQLi."""

    def __init__(self) -> None:
        """Start with an empty state for every IP."""
        self.state: Dict[str, Set[str]] = defaultdict(set)

    def update(self, entry: LogEntry) -> Optional[Dict[str, Any]]:
        """Account for one entry; return a CRITICAL INCIDENT if complete."""
        if not entry.ip:
            return None
        if to_status(getattr(entry, 'status', None)) == 404:
            self.state[entry.ip].add('scanner')
        if getattr(entry, 'attack_type', None) == 'SQLi':
            self.state[entry.ip].add('sqli')
        if {'scanner', 'sqli'} <= self.state[entry.ip]:
            del self.state[entry.ip]
            return {'ip': entry.ip, 'stages': ['scanner', 'sqli'],
                    'alert_type': 'CRITICAL INCIDENT'}
        return None


def correlate_events(entries: Iterable[LogEntry]
                     ) -> Iterator[Dict[str, Any]]:
    """Yield CRITICAL INCIDENT alerts for IPs that scan then inject SQL.

    detect_sqli must already have been applied to the entries.
    """
    correlator = EventCorrelator()
    for entry in entries:
        alert = correlator.update(entry)
        if alert:
            yield alert


# ---------------------------------------------------------------------------
# Task 13 - The Exporter
# ---------------------------------------------------------------------------

def export_report(alerts: List[Any], filename: str,
                  format: str = 'json') -> bool:
    """Write *alerts* (dicts or LogEntry objects) to *filename*.

    Args:
        alerts: Alert dicts and/or LogEntry objects.
        filename: Output path.
        format: Only 'json' is supported (indented, human-readable).

    Returns:
        True on success, False on error (an [ERROR] is printed).
    """
    if format != 'json':
        print(f'[ERROR] Unsupported report format: {format}')
        return False
    records = [alert.to_dict() if isinstance(alert, LogEntry) else alert
               for alert in alerts]
    try:
        with open(filename, 'w', encoding='utf-8') as fh:
            json.dump(records, fh, indent=2)
            fh.write('\n')
    except OSError as exc:
        print(f'[ERROR] Cannot write report {filename}: {exc.strerror}')
        return False
    return True


# ---------------------------------------------------------------------------
# Task 14 - The Multiprocessing
# ---------------------------------------------------------------------------

def process_chunk(lines: List[str]) -> List[LogEntry]:
    """Worker: run the per-line pipeline on a list of raw lines.

    The raw line is no longer needed once the entry is analyzed, so it
    is dropped to keep the results cheap to send back to the parent.

    Returns:
        The processed entries (unparsable lines are dropped).
    """
    results = []
    for entry in map(process_line, lines):
        if entry is not None:
            entry.raw_line = ''
            results.append(entry)
    return results


def parallel_analyze(file_path: str, num_workers: int,
                     chunk_size: int = 10000,
                     stats: Optional[Dict[str, int]] = None
                     ) -> Iterator[LogEntry]:
    """Process *file_path* with a pool of *num_workers* processes.

    Chunks are read lazily and dispatched with Pool.map, a batch of
    chunks at a time, so memory stays bounded; results keep file order.

    Args:
        file_path: Log file to analyze.
        num_workers: Number of worker processes.
        chunk_size: Lines per chunk.
        stats: Optional dict whose 'lines_read' counter is updated.

    Yields:
        Processed LogEntry objects, in file order.
    """
    lines = read_stream(file_path)
    with multiprocessing.Pool(processes=num_workers) as pool:
        while True:
            batch = []
            for _ in range(num_workers * 2):
                chunk = list(islice(lines, chunk_size))
                if not chunk:
                    break
                batch.append(chunk)
            if not batch:
                break
            if stats is not None:
                stats['lines_read'] += sum(len(chunk) for chunk in batch)
            for entries in pool.map(process_chunk, batch):
                yield from entries


def sequential_analyze(file_path: str,
                       stats: Optional[Dict[str, int]] = None
                       ) -> Iterator[LogEntry]:
    """Process *file_path* line by line in the current process.

    Yields:
        Processed LogEntry objects, in file order.
    """
    for line in read_stream(file_path):
        if stats is not None:
            stats['lines_read'] += 1
        entry = process_line(line)
        if entry is not None:
            yield entry


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Build the command-line interface."""
    parser = argparse.ArgumentParser(prog='log_hunter.py')
    parser.add_argument('file', help='log file to analyze')
    parser.add_argument('--report', metavar='FILE',
                        help='export the alerts as JSON to FILE')
    parser.add_argument('--workers', type=int, default=0,
                        help='worker processes (0 = single-threaded)')
    return parser


def main() -> None:
    """Run LogHunter on the file given on the command line."""
    args = build_parser().parse_args()
    print('[*] LogHunter - Log Analysis Engine')
    stats = {'lines_read': 0}
    if args.workers > 0:
        print(f'[*] Reading: {args.file} (parallel: {args.workers} workers)')
        entries = parallel_analyze(args.file, args.workers, stats=stats)
    else:
        print(f'[*] Reading: {args.file}')
        entries = sequential_analyze(args.file, stats)

    counts: Counter = Counter()
    sample = None
    brute_force = BruteForceDetector()
    burst = BurstDetector()
    correlator = EventCorrelator()
    burst_alerts: List[Dict[str, Any]] = []
    incidents: List[Dict[str, Any]] = []

    try:
        for entry in entries:
            if sample is None:
                sample = entry
            counts[entry.service] += 1
            counts['suspicious'] += has_status(entry, (404, 500))
            counts['known_ip'] += entry.country != 'UNKNOWN'
            counts['bots'] += entry.is_bot
            counts['high'] += entry.alert_level == 'HIGH'
            counts[entry.attack_type] += 1
            brute_force.update(entry)
            alert = burst.update(entry)
            if alert:
                burst_alerts.append(alert)
            alert = correlator.update(entry)
            if alert:
                incidents.append(alert)
    except KeyboardInterrupt:
        print('[ERROR] Interrupted by user.')
        sys.exit(130)

    if stats['lines_read'] == 0:
        print('[!] No data to process. Exiting.')
        sys.exit(1)

    total = counts['http'] + counts['ssh']
    print(f"[*] Lines read: {stats['lines_read']}")
    print('--- Parsing ---')
    print(f"[*] Apache lines:  {counts['http']}")
    print(f"[*] Syslog lines:  {counts['ssh']}")
    print(f'[*] Total parsed:  {total}')
    if sample is not None:
        print('[*] Sample entry:')
        print(f"    ip={sample.ip} | service={sample.service} | "
              f"status={getattr(sample, 'status', '-')} | "
              f"path={getattr(sample, 'path', '-')}")

    print('--- Filtering ---')
    print(f"[*] Suspicious (404, 500): {counts['suspicious']}")

    print('--- Enrichment ---')
    print(f"[*] GeoIP: {total} entries enriched "
          f"({counts['known_ip']} known IPs)")
    print(f"[*] Bots detected: {counts['bots']}")

    print('--- Threat Intelligence ---')
    print(f"[*] HIGH alerts: {counts['high']} entries from blacklisted IPs")

    print('--- Attack Detection ---')
    print(f"[*] SQLi attempts: {counts['SQLi']}")
    print(f"[*] XSS attempts:  {counts['XSS']}")

    brute_alerts = list(brute_force.alerts())
    print('--- Brute Force ---')
    print(f'[*] BRUTE_FORCE alerts: {len(brute_alerts)}')
    for alert in brute_alerts:
        print(f"    {alert['ip']}: {alert['count']} failures")

    print('--- Burst Detection ---')
    print(f'[*] BURST alerts: {len(burst_alerts)}')
    for alert in burst_alerts:
        print(f"    {alert['ip']}: {alert['count']} requests in "
              f"{alert['window']}s window")

    print('--- Correlation ---')
    print('[*] CRITICAL INCIDENTS:')
    for alert in incidents:
        print(f"    {alert['ip']}: {' -> '.join(alert['stages'])}")
    if not incidents:
        print('    None')

    all_alerts = brute_alerts + burst_alerts + incidents
    print()
    if args.report:
        if not export_report(all_alerts, args.report):
            sys.exit(1)
        print(f'[*] Report exported: {args.report} '
              f'({len(all_alerts)} alerts)')
    else:
        print(f'[*] Total alerts: {len(all_alerts)}')
        print('[*] Use --report <file> to export.')


if __name__ == '__main__':
    main()
