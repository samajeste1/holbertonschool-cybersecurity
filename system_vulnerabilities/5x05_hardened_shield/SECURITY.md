# Security architecture

## Architecture Overview

The Hardened Shield is a single Ubuntu image that serves HTTP on port 80 and SSH on port 22. Process 1 is a small supervisor. It applies configuration, starts nginx and sshd, and restarts them if they exit.

nginx is the web workload. Its worker processes run as the unprivileged `www-data` account. Remote administration uses the `appuser` account over SSH. The root password is locked. Secrets are not written into the image: the operator SSH key is generated on a Docker volume the first time the container starts.

```
Internet
   │
   ├── :80  nginx (master as root, workers as www-data)
   └── :22  sshd (public key, appuser only)
            │
            └── read-only root filesystem
                dropped capabilities
                no-new-privileges
```

## Security Controls

| Domain | Control | Where it is applied |
|---|---|---|
| Kernel | `ip_forward=0`, `rp_filter=1`, `tcp_syncookies=1`, redirects and source routing off | `init-hardening.sh` |
| Filesystem | `noexec,nosuid,nodev` on `/tmp` and `/dev/shm` | `init-hardening.sh` and compose tmpfs |
| Services | Compilers removed, unused daemons disabled when systemd exists | `init-hardening.sh` |
| SUID | Non-essential SUID bits removed | `init-hardening.sh` |
| Banner | `/etc/issue.net` shown before SSH login | `init-hardening.sh` |
| Passwords | PAM pwquality, minimum 12 characters, history 5, 90-day aging | `init-identity.sh` |
| Lockout | faillock deny 5, unlock after 900 seconds; fail2ban jail file for sshd | `init-identity.sh` |
| SSH | `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries 3` | `init-identity.sh` |
| Root | `passwd -l root` | `init-identity.sh` |
| Runtime | `cap_drop: ALL`, selected caps added back, `no-new-privileges`, 512 MB, 100 pids | `docker-compose.yml` |

## Usage Instructions

1. Build and start with `docker compose up -d --build`.
2. Confirm the site with `curl -fsS http://127.0.0.1/`.
3. Read the generated public key from `/home/appuser/.ssh/id_ed25519.pub` inside the container.
4. Copy the matching private key out of the `app-ssh` volume and store it in the team password manager. Do not commit it.
5. Connect with `ssh -i <key> -p 22 appuser@127.0.0.1`.

Password login is disabled on purpose. There is no default password to rotate.

## Audit Procedures

Run the auditor inside the running container:

```bash
docker compose exec hardened python3 /opt/novatech/scripts/audit.py -o /tmp/audit_result.md
docker compose exec hardened cat /tmp/audit_result.md
```

The tool prints a score per category, an overall percentage, and a pass/fail status. A score of 80 percent or higher is a pass. Investigate every FAIL line before the image is promoted.

Manual checks:

- `docker inspect novatech-hardened-shield` shows `ReadonlyRootfs` true and a dropped capability set.
- `sshd -T` inside the container reports `permitrootlogin no` and `passwordauthentication no`.
- `passwd -S root` reports the account locked.

## Maintenance Guidelines

- Rebuild the image monthly so Ubuntu security updates are included. Do not install compilers into the runtime image.
- Keep `init-hardening.sh` and `init-identity.sh` idempotent. A second run must exit 0.
- Replace the generated admin key on a schedule. Remove the volume and start once to mint a new key, then distribute it.
- Do not add secrets to the Dockerfile, compose file, or `config/`. Inject them at runtime if a future application needs them.
- Review `audit.py` whenever a control changes so the score still describes the image that is actually running.
