# The Hardened Shield

Production base image for NovaTech Solutions. It packages the system hardening from project 5x02, the identity controls from project 5x03, and the container restrictions from project 5x04 into one image that needs no manual steps after start.

## Quick start guide

```bash
cd system_vulnerabilities/5x05_hardened_shield
docker compose build
docker compose up -d
curl -fsS http://127.0.0.1/
docker compose exec hardened python3 /opt/novatech/scripts/audit.py -o /tmp/audit_result.md
```

SSH listens on port 22. Authentication is by key only. The private key is created on the `app-ssh` volume at first start and is not stored in the image:

```bash
docker compose exec hardened cat /home/appuser/.ssh/id_ed25519.pub
```

## File structure

```
5x05_hardened_shield/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── SECURITY.md
├── COMPLIANCE_REPORT.md
├── audit_result.md
├── scripts/
│   ├── entrypoint.sh
│   ├── init-hardening.sh
│   ├── init-identity.sh
│   ├── init-services.sh
│   └── audit.py
└── config/
    └── www/index.html
```

## Build and run instructions

Build on Ubuntu 20.04 or later with Docker:

```bash
docker compose build
docker compose up -d
docker compose ps
```

The entrypoint runs hardening, identity, and service checks, then keeps nginx and sshd running. Re-running the scripts does not undo a correct configuration.

Stop the stack with `docker compose down`.

## Security features summary

- Kernel parameters: forwarding off, reverse-path filter, SYN cookies, redirects and source routing blocked
- Filesystem: `noexec`, `nosuid`, and `nodev` for temporary filesystems
- SUID reduction and removal of compilers when they are present
- PAM password length 12, history 5, aging 90 days, faillock after 5 failures
- SSH: root login off, passwords off, public keys only, legal banner
- Root account locked
- nginx workers run as a non-root user; `appuser` is the administrative identity
- Container: read-only root, capabilities dropped, `no-new-privileges`, memory and process limits
- `audit.py` scores kernel, filesystem, identity, service, and container controls
