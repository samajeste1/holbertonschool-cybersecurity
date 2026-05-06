# Linux Hardening Capstone

Production-grade server hardening automation for Ubuntu 22.04 (STIG-2024 compliance).

## Usage

```bash
sudo bash harden.sh
```

## Structure

```
hardening/
├── harden.sh              # Main entry point
├── config/
│   └── harden.cfg         # Configuration variables
├── lib/
│   ├── network.sh         # Network hardening functions
│   ├── ssh.sh             # SSH hardening functions
│   ├── identity.sh        # User/password functions
│   └── system.sh          # System hardening functions
└── README.md              # Documentation
```

## Output

- Logs: `/var/log/hardening.log`
- Report: `audit_report.txt`
