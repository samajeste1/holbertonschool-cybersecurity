# Access Control Policy — Nexus Financial

**Document Reference:** NX-SEC-ACP-001
**Version:** 1.0
**Author:** Interim CISO
**Effective:** Immediately upon publication
**Scope:** All systems, users, networks, and credentials within Nexus Financial's environment

---

## Executive Summary

This policy eliminates the shared `nexus_master.pem` key, enforces individual accountability for all system access, implements the principle of least privilege across all user roles, and defines network access controls that close the open database port without preventing the remote development team from working. Every rule in this document has a corresponding implementation in `technical/rbac_setup.sh` and `technical/network_defense.sh`.

---

## Section 1: Authentication Policy

### 1.1 Password and PIN Requirements

- Minimum length: 16 characters for service accounts, 12 characters for user accounts.
- Composition: at least one uppercase, one lowercase, one digit, one special character.
- The CEO's admin panel PIN of `1975` is **revoked immediately**. The admin panel must implement full password authentication with MFA.
- Passwords may not be written on any physical surface, stored in plaintext files, or transmitted via instant messaging (including Slack).
- All credentials must be stored in the company-approved password manager (1Password Teams or Bitwarden Business). Personal password manager use for work credentials is prohibited.
- Password reuse across systems is prohibited. Staging credentials must be distinct from production credentials.

### 1.2 SSH Key Management

**The `nexus_master.pem` practice is terminated effective immediately.**

Replacement policy:

- Every engineer who requires SSH access to production servers is issued a **unique, individual ed25519 keypair** generated on their own machine.
- The private key never leaves the engineer's machine. The public key is added to the authorized_keys of the specific server(s) they are authorized to access.
- The shared `nexus_master.pem` key is **revoked from all servers immediately** (remove from `~/.ssh/authorized_keys` on all hosts).
- The `nexus_master.pem` file must be deleted from all machines and the Slack message containing it must be deleted. The channel `#dev-ops` must be audited for all credential disclosures.
- Emergency production access outside business hours is handled via a **Break Glass procedure**: a sealed, time-limited emergency key stored in the password manager, accessible only by the CTO and CISO, with mandatory post-use review and immediate rotation.
- SSH keys must use ed25519 or RSA-4096 minimum. RSA-2048 and DSA keys are prohibited.

Implementation note for `rbac_setup.sh`: Generate individual keys for each role, configure `sshd` to disable password authentication, and restrict which users can SSH to which hosts.

### 1.3 Multi-Factor Authentication (MFA)

- MFA is **mandatory** for: admin panel access, AWS console access, all remote access (VPN), and the password manager.
- MFA method: TOTP authenticator app (Google Authenticator, Authy). SMS-based MFA is prohibited for production systems.
- MFA bypass is prohibited under any circumstances. Requests to disable MFA "temporarily" are denied by default and require written CISO approval.

---

## Section 2: Authorization Policy — RBAC Model

### 2.1 Role Definitions

| Role | Members | Access Scope | Restrictions |
|------|---------|-------------|-------------|
| `sysadmin` | Interim CISO only | Full system configuration, user management, firewall | Cannot disable logging or audit trail |
| `ops` | CTO (Dave) | Read-only access to system logs, service status monitoring | Cannot modify config files, cannot SSH to production directly |
| `devs` | Lead Developer (Sarah) + developers | Deploy code, restart application services (nginx, app server), read application logs | Cannot access database directly, cannot modify firewall rules |
| `auditors` | External auditor | Read-only access to logs in `/var/log/audit/` and `/var/log/app/` | No write access anywhere, no SSH |
| `db_service` | Database service account only | Read/write to assigned database schemas only | Cannot access other schemas, cannot create users |

### 2.2 Principle of Least Privilege

- Every user receives the minimum permissions required to perform their job function. No exceptions granted for convenience.
- Sarah (Lead Dev) can restart nginx without root: implemented via sudoers entry `devs ALL=(root) NOPASSWD: /bin/systemctl restart nginx`.
- Dave (CTO) can read logs without editing config: implemented via group `ops` with read permission on `/var/log/` and explicit deny on `/etc/`.
- No user has unrestricted root access in production. Root login via SSH is disabled. `sudo -i` and `sudo su` are prohibited in sudoers.

### 2.3 Sudoers Policy

The following sudoers configuration is enforced (implemented in `rbac_setup.sh`):

```
# Devs: restart application services only
%devs ALL=(root) NOPASSWD: /bin/systemctl restart nginx, /bin/systemctl restart app

# Ops: read logs only, no config access
%ops ALL=(root) NOPASSWD: /bin/journalctl, /bin/cat /var/log/*

# Sysadmin: full sudo with password and logging
%sysadmin ALL=(ALL:ALL) ALL

# Explicitly deny dangerous commands for all non-sysadmin
Cmnd_Alias DANGER = /bin/rm, /bin/dd, /usr/bin/shred, /bin/mkfs
%devs !DANGER
%ops !DANGER
```

### 2.4 Database Authorization

- The PostgreSQL database is not directly accessible to any human user in normal operations. All application access goes through the application service account (`db_service`) with a randomly generated 32-character password.
- The remote frontend team in Bali accesses data through the **application API** over HTTPS, not directly over port 5432. Direct database access for remote teams is prohibited.
- Database administrative access (schema changes, user management) requires a separate admin account, accessed only from the bastion host, with all sessions logged.

---

## Section 3: Network Access Policy

### 3.1 Default Deny

The network firewall policy is **default deny**. All traffic is blocked unless explicitly permitted by a documented rule with a business justification.

### 3.2 Permitted Traffic Rules

| Rule | Source | Destination | Port | Protocol | Justification |
|------|--------|------------|------|----------|---------------|
| HTTPS-IN | `0.0.0.0/0` | Web server | 443 | TCP | Public web application |
| SSH-BASTION | Bastion host IP only | All servers | 22 | TCP | Secure remote administration |
| DB-APP | Web server private IP only | DB server | 5432 | TCP | Application-to-database only |
| LOG-OUT | All internal | Log server | 514 | UDP | Centralized logging |

### 3.3 Explicitly Prohibited Rules

- Port 5432 (PostgreSQL) open to `0.0.0.0/0` — **terminated immediately**.
- Port 22 (SSH) open to `0.0.0.0/0` — **terminated immediately**. SSH accessible only from bastion host.
- Any rule with source `0.0.0.0/0` on internal service ports is prohibited.

### 3.4 Remote Access for Bali Frontend Team

The Bali team accesses Nexus Financial systems via:
1. **API over HTTPS** for all data access (no direct DB connection).
2. **WireGuard VPN** for any development environment access requiring internal network visibility. VPN credentials are individual (not shared) and subject to the same MFA requirement as all remote access.

Implementation note: WireGuard VPN setup is outside the 5-day scope but is documented as a Day 10 deliverable.

---

## Section 4: Account Lifecycle Policy

### 4.1 Provisioning

- All accounts are created with explicit approval from the CISO and documented with: employee name, role, systems granted access, date of provisioning, and approver.
- Default accounts and passwords on all systems must be changed before the system enters production.

### 4.2 Offboarding

- All accounts and credentials for departing employees must be revoked within **1 hour** of confirmed departure.
- SSH public keys of departing employees must be removed from all `authorized_keys` files immediately.
- If a departing employee had access to the shared `nexus_master.pem` (all current developers did): the key is considered compromised and must be rotated as part of offboarding. This is already being executed as part of this engagement.

### 4.3 Quarterly Access Review

- Every quarter, the CISO reviews all active accounts, permissions, and SSH keys.
- Any account that has not been used in 90 days is disabled pending review.
- Shared accounts (except documented service accounts) are prohibited.
