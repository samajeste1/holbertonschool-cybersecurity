# IntelBroker

Automated IP intelligence aggregator that combines live Nmap scans with
async threat-intelligence API queries (VirusTotal, Shodan, AbuseIPDB).

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Usage

Start the mock API server in a separate terminal:

```bash
./mock_api.py
```

Run IntelBroker:

```bash
./intel_broker.py 1.2.3.4
./intel_broker.py 1.2.3.4 -o report.json -v
```

## File structure

| File | Purpose |
|---|---|
| `intel_broker.py` | CLI entry point |
| `api_client.py` | Async HTTP logic (aiohttp, cache, rate limiter) |
| `scanner.py` | Nmap wrapper + XML parser |
| `models.py` | TargetDossier data model |
| `mock_api.py` | Local mock server for VirusTotal/Shodan/AbuseIPDB |

## API keys

Never hardcode API keys in source files. Store them as environment
variables and read them with `os.getenv("VT_API_KEY")`.
