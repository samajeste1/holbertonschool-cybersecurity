# Access Control Policy — Nexus Financial

**Document Reference:** NX-SEC-ACP-001
**Version:** 1.0
**Author:** Interim CISO
**Effective:** Immediately
**Scope:** All systems, users, networks, and credentials within Nexus Financial's environment

---

## Executive Summary

This policy eliminates the shared `nexus_master.pem` key, enforces individual accountability, implements least-privilege RBAC, and defines exact network rules that close the open database port. Every rule maps directly to implementation commands in `technical/rbac_setup.sh` and `technical/network_defense.sh`.

---

## Section 1: Authentication

### 1.1 SSH Key Management

**Policy:** The shared `nexus_master.pem` key is revoked immediately. Each engineer receives an individual `ed25519` keypair.

**Implementation commands (executed by `rbac_setup.sh`):**

```bash
# Generate individual key per user (run as each user)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "username@nexus-financial"

# Remove shared master key from all authorized_keys
sed -i '/nexus_master/d' /home/*/.ssh/authorized_keys
sed -i '/nexus_master/d' /root/.ssh/authorized_keys

# Disable password auth and root login in sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl restart ssh
```

**Accepted key types:** `ed25519` or `rsa-4096` only. RSA-2048 and DSA are prohibited.

**Break Glass procedure:** One emergency key stored in password manager, accessible only by CTO + CISO. Mandatory rotation after each use.

### 1.2 Password Policy

**Policy:** Minimum 16 characters, enforced via PAM `pwquality`.

**Implementation (`/etc/security/pwquality.conf`):**

```
minlen = 16
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
reject_username = yes
```

**Password expiry (`/etc/login.defs`):**

```
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
```

**CEO admin panel PIN `1975`:** Revoked immediately. Replaced with 16-character random password + TOTP MFA.

### 1.3 Multi-Factor Authentication

**Policy:** MFA required on all remote access, AWS console, and admin panel.

**Method:** TOTP authenticator app (Google Authenticator or Authy). SMS MFA is prohibited.

---

## Section 2: Authorization — RBAC Model

### 2.1 Groups and Roles

| Group | Members | Primary Function |
|-------|---------|-----------------|
| `sysadmin` | `nexus_admin` (CISO) | Full system administration |
| `devs` | `sarah`, developers | Deploy code, restart app services |
| `ops` | `dave` (CTO) | Read logs, monitor services |
| `auditors` | `auditor` | Read audit logs only |

**Implementation commands:**

```bash
groupadd sysadmin
groupadd devs
groupadd ops
groupadd auditors

useradd -m -s /bin/bash -g sysadmin nexus_admin
useradd -m -s /bin/bash -g devs sarah
useradd -m -s /bin/bash -g ops dave
useradd -m -s /bin/bash -g auditors auditor
```

### 2.2 File Permissions per Role

| Path | Owner | Permissions | Accessible by |
|------|-------|-------------|---------------|
| `/home/nexus_admin/` | `nexus_admin:sysadmin` | `700` | sysadmin only |
| `/home/sarah/` | `sarah:devs` | `700` | sarah only |
| `/home/dave/` | `dave:ops` | `700` | dave only |
| `/home/auditor/` | `auditor:auditors` | `700` | auditor only |
| `/var/log/` | `root:adm` | `750` | root + adm; read by ops/auditors via ACL |
| `/var/log/audit/` | `root:root` | `750` | auditors: `r-x` via `setfacl` |
| `/etc/` | `root:root` | `755` | devs: `---` via `setfacl`; ops: `r-x` |

**Implementation commands:**

```bash
chmod 700 /home/nexus_admin /home/sarah /home/dave /home/auditor

# ACL: ops can read logs, devs cannot touch /etc
setfacl -R -m g:ops:rx /var/log/
setfacl -R -m g:auditors:rx /var/log/audit/
setfacl -m g:devs:--- /etc/
setfacl -m g:ops:r-x /etc/
```

### 2.3 Sudoers Rules — Least Privilege

**File:** `/etc/sudoers.d/nexus_rbac` (mode `440`)

```
# sysadmin — full sudo with password
%sysadmin ALL=(ALL:ALL) ALL

# devs — restart nginx and app only, no password required
%devs ALL=(root) NOPASSWD: /bin/systemctl restart nginx
%devs ALL=(root) NOPASSWD: /bin/systemctl restart app
%devs ALL=(root) NOPASSWD: /bin/systemctl status nginx
%devs ALL=(root) NOPASSWD: /bin/systemctl status app
%devs ALL=(root) NOPASSWD: /usr/bin/journalctl -u nginx
%devs ALL=(root) NOPASSWD: /usr/bin/journalctl -u app

# ops — read logs only, no service management
%ops ALL=(root) NOPASSWD: /usr/bin/journalctl
%ops ALL=(root) NOPASSWD: /bin/systemctl status *

# auditors — read audit logs only
%auditors ALL=(root) NOPASSWD: /usr/bin/aureport
%auditors ALL=(root) NOPASSWD: /usr/bin/ausearch

# Deny root shell to all non-sysadmin
%devs ALL=(root) !/bin/bash, !/bin/sh, !/usr/bin/su
%ops ALL=(root) !/bin/bash, !/bin/sh, !/usr/bin/su
%auditors ALL=(root) !/bin/bash, !/bin/sh, !/usr/bin/su
```

**Sarah (devs) can restart nginx without root — verified by:**

```bash
sudo -u sarah sudo systemctl restart nginx   # ALLOWED
sudo -u sarah sudo vim /etc/nginx/nginx.conf # DENIED
```

**Dave (ops) reads logs without editing config — verified by:**

```bash
sudo -u dave sudo journalctl -n 50   # ALLOWED
sudo -u dave sudo vim /etc/ssh/sshd_config  # DENIED
```

---

## Section 3: Network Access Rules

### 3.1 Firewall — UFW Default Deny

**Policy:** All traffic is blocked unless explicitly permitted. Implemented by `technical/network_defense.sh`.

```bash
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed
```

### 3.2 Permitted Rules

| Service | Source | Destination Port | Protocol | Justification |
|---------|--------|-----------------|---------|---------------|
| HTTPS | `0.0.0.0/0` | `443` | TCP | Public web application |
| HTTP | `0.0.0.0/0` | `80` | TCP | Redirect to HTTPS only |
| SSH | `192.168.1.10` (bastion) | `22` | TCP | Admin access via bastion only |
| PostgreSQL | `192.168.1.20` (web server) | `5432` | TCP | App-to-DB only — no internet |
| WireGuard VPN | `0.0.0.0/0` | `51820` | UDP | Remote team (Bali) VPN entry |
| Syslog | Internal | `192.168.1.50:514` | UDP/TCP | Centralized log server |
| DNS | Internal | `53` | UDP/TCP | Name resolution |
| NTP | Internal | `123` | UDP | Time synchronization |

**Implementation commands:**

```bash
ufw allow in from 192.168.1.10 to any port 22 proto tcp     # SSH: bastion only
ufw allow in from 192.168.1.20 to any port 5432 proto tcp   # DB: web server only
ufw allow in to any port 443 proto tcp                       # HTTPS public
ufw allow in to any port 51820 proto udp                     # WireGuard VPN
```

### 3.3 Bali Remote Team — VPN Solution

The Bali team previously required direct port 5432 access. This is replaced by:

1. **WireGuard VPN** — each Bali developer receives individual VPN credentials.
2. VPN grants access to the **HTTPS API** (`192.168.1.20:443`) only — not direct DB access.
3. VPN credentials are individual (not shared), subject to MFA, and rotated quarterly.

```bash
# VPN subnet: 10.8.0.0/24
# Bali team HTTPS access via VPN:
ufw allow in from 10.8.0.0/24 to any port 443 proto tcp
# Bali team DB access: BLOCKED (default deny covers 5432 from VPN subnet)
```

---

## Section 4: Account Lifecycle

### 4.1 Offboarding — Immediate Revocation (within 1 hour)

```bash
# Disable account
usermod -L <username>
# Remove SSH keys
echo "" > /home/<username>/.ssh/authorized_keys
# Revoke sudo if applicable
rm -f /etc/sudoers.d/<username>
# Lock any service accounts the user knew credentials for (rotate passwords)
```

### 4.2 Quarterly Access Review

- All accounts unused for 90 days are disabled pending review.
- All SSH public keys are audited: `find /home -name authorized_keys -exec cat {} \;`
- Sudoers entries are reviewed for scope creep.
