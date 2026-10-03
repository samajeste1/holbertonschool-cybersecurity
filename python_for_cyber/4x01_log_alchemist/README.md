# LogHunter - The Log Alchemist

Streaming log analysis engine for Apache/Nginx access logs and syslog.
LogHunter reads huge files line by line (generators), normalizes both
formats into `LogEntry` objects, enriches them, detects attacks, correlates
multi-step incidents and exports the alerts as JSON.

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requierment.txt
chmod +x log_hunter.py
```

## Usage

```bash
./log_hunter.py huge_access.log
./log_hunter.py huge_access.log --report report.json
./log_hunter.py huge_access.log --workers 4 --report report.json
```

| Option | Description |
|---|---|
| `file` | Log file to analyze (required) |
| `--report FILE` | Export all alerts to FILE as indented JSON |
| `--workers N` | Parse with N processes (`multiprocessing.Pool`), 0 = single process |

## Pipeline

```
read_stream -> parse (Apache regex, then syslog regex) -> normalize_entry
  -> enrich_ip -> analyze_user_agent -> check_threat_intel
  -> detect_sqli -> detect_xss
  -> brute force / burst / correlation (stateful, one pass) -> export_report
```

| Stage | Function | Detection |
|---|---|---|
| Stream | `read_stream` | Generator, constant memory |
| Parsing | `parse_apache_line`, `parse_syslog_line` | Pre-compiled regex with named groups |
| Normalization | `LogEntry`, `normalize_entry` | Common fields: ip, timestamp, service, message, raw_line |
| Filter | `filter_logs` | Keeps given status codes (404, 500 by default) |
| GeoIP | `enrich_ip` | `country` from `GEOIP_DB`, `UNKNOWN` otherwise |
| Bots | `analyze_user_agent` | sqlmap, nikto, curl, python (case-insensitive) |
| Threat intel | `check_threat_intel` | `alert_level` HIGH for `BLACKLIST` IPs |
| SQLi | `detect_sqli` | UNION SELECT, `' OR 1=1`, `'--`, stacked queries, sleep(), URL-decoded |
| XSS | `detect_xss` | `<script`, `javascript:`, `on*=`, `<img/svg/iframe`, URL-decoded |
| Brute force | `detect_bruteforce` | More than 5 HTTP 401 / SSH "Failed password" per IP |
| Burst | `detect_burst` | 10 events in a 60 s sliding window per IP |
| Correlation | `correlate_events` | 404 scan + SQLi from the same IP = CRITICAL INCIDENT |
| Export | `export_report` | Indented JSON list of alerts |
| Scale | `process_chunk`, `parallel_analyze` | Chunks dispatched with `Pool.map` |

The whole file is analyzed in a single pass: the stateful detectors keep
only per-IP counters and time windows, never the full list of entries.
