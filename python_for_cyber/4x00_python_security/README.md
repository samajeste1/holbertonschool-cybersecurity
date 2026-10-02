# BreachCheck

Automated auditor for leaked credential files. BreachCheck reads a leak
(`email:password` per line), drops garbage and malformed lines, flags weak
passwords against a configurable policy, and writes a JSON report in which
passwords only appear as salted SHA-256 hashes.

Standard library only.

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt   # pycodestyle, for linting only
chmod +x breach_check.py utils.py tests.py
```

## Usage

```bash
./breach_check.py --help
./breach_check.py --file leak.txt
./breach_check.py --file leak.txt --output report.json --verbose
```

| Option | Description |
|---|---|
| `-f`, `--file` | Input leak file (required) |
| `-o`, `--output` | Write the JSON report to this file |
| `-v`, `--verbose` | Show debug messages on the console |

Console shows INFO messages; `breach_check.log` receives DEBUG messages.

## Policy (`config.ini`)

```ini
[SECURITY]
salt = <secret salt>
min_length = 8
common_passwords = password, 123456, qwerty
```

A password is **WEAK** if it is shorter than `min_length`, has no digit,
is digits only, or is in `common_passwords`. Otherwise it is **COMPLIANT**.

## Files

| File | Purpose |
|---|---|
| `breach_check.py` | CLI entry point, logging, config, policy engine, report |
| `utils.py` | Lazy file reader (generator), cleaning, validation, hashing |
| `config.ini` | Security policy (salt, minimum length, common passwords) |
| `tests.py` | Unit tests (`python3 tests.py`) |

## Tests

```bash
python3 tests.py
```
