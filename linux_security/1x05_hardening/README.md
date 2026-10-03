# Linux Hardening Capstone

Production-grade server hardening automation for Ubuntu 22.04 (STIG-2024
compliance). Turns a fresh server into a hardened bastion host. Modular,
configuration-driven, idempotent (safe to run repeatedly).

## Usage

```bash
chmod +x harden.sh
sudo ./harden.sh
cat audit_report.txt
```

The script refuses to run without root privileges.

## Structure

```
hardening/
├── harden.sh              # Entry point: root check, config, logging, report helpers
├── config/
│   └── harden.cfg         # All tunable values and file paths
├── lib/
│   ├── network.sh         # Firewall policy file, kernel network parameters
│   ├── ssh.sh             # SSH port, key-only auth, no root login, verification
│   ├── identity.sh        # Password policy, lockout, unauthorized users, root lock
│   └── system.sh          # Updates, package removal/installation, audit report
└── README.md
```

## Controls applied

| ID | Control |
|---|---|
| N-01/N-02 | Firewall policy file: default inbound deny, SSH/80/443 allowed |
| N-03 | `net.ipv4.ip_forward=0`, `net.ipv4.icmp_echo_ignore_all=1` |
| S-01/S-02 | SSH on custom port, `PasswordAuthentication no`, `PubkeyAuthentication yes`, `PermitRootLogin no` in `sshd_config` and in any `sshd_config.d/*.conf` that overrides them (validated with `sshd -t`, effective values checked with `sshd -T`) |
| I-01 | `pam_pwquality` in `/etc/pam.d/common-password` and `pwquality.conf`: `minlen=12`, `ucredit/lcredit/dcredit/ocredit=-1` (upper, lower, digit, special); `PASS_MAX_DAYS 90` in `login.defs` |
| I-02 | `pam_faillock` in `common-auth`/`common-account`, `deny=5` (also in `faillock.conf`) |
| I-03 | Deletion of users with UID > 1000 not in `sudo`/`wheel` (`ALLOWED_SSH_USERS` and the admin running the script are always kept) |
| I-04 | Root password locked |
| H-01..03 | Non-interactive update/upgrade, purge of `BLOATWARE`, installation and activation of `REQUIRED_TOOLS` |

PAM and SSH files are backed up once (`*.orig`) before their first modification.

## Logging and audit report

- Every action is logged with a timestamp and a level to `/var/log/hardening.log`:
  `[2024-01-15 14:32:01] [INFO] SSH configured on port 2222.`
- At the end, `audit_report.txt` is written in the **current directory**. It lists
  the changes actually applied (with counts), then every `[WARN]` and `[ERROR]`
  met during the run, then the compliance status: `PASS` when no error occurred,
  `FAIL` otherwise.

```
===============================================
 HARDENING AUDIT REPORT - 2024-01-15 14:32:01
===============================================

[INFO] Hardening procedure completed successfully.
[INFO] SSH configured on port 2222.
[INFO] Firewall policy created (/etc/hardening/firewall.rules): ports 2222, 80, 443 ALLOWED, default inbound DENY.
[INFO] 3 unauthorized users removed: guest, temp, test.
[INFO] Installed 2 package(s): auditd, fail2ban.
[INFO] Removed 3 package(s): telnet, ftp, netcat-traditional.
[WARN] Package updates skipped (already up to date).

===============================================
 COMPLIANCE STATUS: PASS
===============================================
```

## Idempotence

Settings are replaced in place (never duplicated), packages and users are only
touched when needed, and `sshd_config` is backed up once to `sshd_config.orig`.
A second run changes nothing and reports "none" / "0" for each action.
