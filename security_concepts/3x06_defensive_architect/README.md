# Nexus Financial — Defensive Security Architecture

**Engagement:** Interim CISO — 5-Day Emergency Security Program
**Client:** Nexus Financial (FinTech, pre-IPO)
**Consultant:** DefendSec Consulting
**Classification:** Confidential

---

## Master Architecture Document

This repository contains the complete security program implemented for Nexus Financial in preparation for their IPO external audit. The engagement addressed critical vulnerabilities discovered during the initial site walkthrough: an internet-exposed PostgreSQL database, a shared SSH master key distributed via Slack, no firewall policy, no audit logging, no RBAC, and a physically compromised server room.

---

## Repository Structure

```
3x06_defensive_architect/
├── policy/                      # Governance Documents
│   ├── threat_model.md          # STRIDE analysis of all assets
│   ├── access_control_policy.md # AuthN, AuthZ, Network rules
│   ├── physical_security_plan.md# Physical + human security plan
│   └── incident_response_plan.md# IR playbook: Compromised Database
├── technical/                   # Implementation Scripts
│   ├── hardening.sh             # System baseline hardening
│   ├── rbac_setup.sh            # Groups, users, sudoers, SSH keys
│   ├── network_defense.sh       # UFW default deny + micro-segmentation
│   └── logging_setup.sh         # Auditd + rsyslog centralized logging
└── audit/                       # Proof of Compliance
    └── final_report.md          # Auditor-facing verification report
```

---

## Critical Vulnerabilities — Before vs After

| Vulnerability | Day 1 | Day 5 |
|--------------|-------|-------|
| PostgreSQL port 5432 open to internet | CRITICAL | CLOSED — internal only |
| `nexus_master.pem` shared in Slack | CRITICAL | REVOKED — individual ed25519 keys |
| No firewall (default allow) | CRITICAL | UFW default deny enforced |
| Root SSH enabled | HIGH | Disabled |
| No audit logging | HIGH | Auditd + centralized rsyslog |
| No RBAC (all users = root) | HIGH | Groups, sudoers, least privilege |
| Admin panel PIN: 1975 | HIGH | MFA enforced |
| Physical server room open | HIGH | Locked, access logged |
| Credentials on whiteboard | HIGH | Erased — policy enforced |
| Unlocked workstations | MEDIUM | Auto-lock 2min enforced |

---

## How to Deploy

All scripts are idempotent — safe to run multiple times.

```bash
# 1. Run as root on Ubuntu 20.04+

# System hardening baseline
chmod +x technical/hardening.sh
sudo ./technical/hardening.sh

# RBAC: groups, users, SSH keys, sudoers
chmod +x technical/rbac_setup.sh
sudo ./technical/rbac_setup.sh

# Network defense: UFW default deny + port rules
# Set environment variables for your IPs first:
export BASTION_IP="10.0.0.10"
export WEB_SERVER_IP="10.0.1.20"
export LOG_SERVER_IP="10.0.0.50"
chmod +x technical/network_defense.sh
sudo ./technical/network_defense.sh

# Logging: auditd + rsyslog centralized forwarding
export CENTRAL_LOG_SERVER="10.0.0.50"
chmod +x technical/logging_setup.sh
sudo ./technical/logging_setup.sh
```

---

## Architecture Summary

### Defense in Depth Layers Implemented

```
Internet
    │
    ▼
[UFW Firewall — Default Deny]
    │ Allow: 443 (HTTPS), 80 (redirect), 51820 (VPN)
    │ Block: 5432, 22 (from internet), all others
    ▼
[Web Server — 10.0.1.20]
    │ Only this IP can reach DB on port 5432
    ▼
[PostgreSQL Database — internal only]
    │
    ▼
[Auditd — all DB access logged]
    │
    ▼
[Rsyslog → Central Log Server 10.0.0.50]
    (logs forwarded in real time — survive local compromise)
```

### RBAC Model

```
sysadmin (nexus_admin)  → Full sudo with password
devs (sarah)            → Restart nginx/app only — no config access
ops (dave)              → Read logs only — no service management
auditors (auditor)      → Read audit logs only — no write access
```

---

## Residual Risks (Accepted for IPO Scope)

1. **WireGuard VPN** not yet deployed (Day 10 deliverable) — Bali team uses API only
2. **S3 backup integrity** unverified (Kevin's script) — Day 7 action item
3. **Application security** (OWASP Top 10) — requires separate engagement
4. **WeWork co-working space** — persistent physical risk, recommend private office by Day 90

---

## References

- NIST Cybersecurity Framework (CSF 2.0)
- CIS Benchmarks for Ubuntu Linux 20.04
- OWASP Top 10 Proactive Controls
- NIST SP 800-61 (Incident Response)
- NIST SP 800-53 Rev. 5 (Security Controls)
