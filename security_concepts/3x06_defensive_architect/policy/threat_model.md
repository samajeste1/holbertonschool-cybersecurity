# Threat Model — Nexus Financial

**Document Reference:** NX-SEC-TM-001
**Version:** 1.0
**Author:** Interim CISO — DefendSec Consulting
**Date:** Day 1 of 5-day engagement
**Classification:** Confidential

---

## Methodology: STRIDE Analysis

STRIDE is a threat modeling framework that classifies threats into six categories:
- **S**poofing — Impersonating a user, system, or identity
- **T**ampering — Modifying data or code without authorization
- **R**epudiation — Denying actions without proof they occurred
- **I**nformation Disclosure — Exposing data to unauthorized parties
- **D**enial of Service — Disrupting availability of systems or services
- **E**levation of Privilege — Gaining unauthorized access rights

---

## Asset Inventory

| Asset ID | Asset | Sensitivity | Location |
|----------|-------|-------------|----------|
| A-01 | PostgreSQL production database (port 5432, open to internet) | Critical | Cloud (AWS) |
| A-02 | `nexus_master.pem` SSH key (pinned in Slack #dev-ops) | Critical | Slack + all dev machines |
| A-03 | Production servers (AWS EC2) | Critical | Cloud |
| A-04 | S3 backup bucket (Kevin's script, unverified) | High | AWS S3 |
| A-05 | Admin panel (CEO PIN: 1975) | Critical | Web application |
| A-06 | Physical server room "The Core" (propped door) | High | WeWork office |
| A-07 | Workstations (80% unlocked at lunch) | High | Open-plan office |
| A-08 | Whiteboard (Wi-Fi pwd, staging DB pwd, CEO Netflix) | High | Office common area |
| A-09 | Generic keycards + spare card box | High | Office physical access |
| A-10 | Guest Wi-Fi network | Medium | WeWork shared space |

---

## STRIDE Analysis

### Component 1 — PostgreSQL Database (A-01)

**Configuration:** Port 5432 open to `0.0.0.0/0` (entire internet).

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Attacker authenticates using leaked credentials | ✅ **TOP** |
| Tampering | Authenticated attacker modifies or deletes financial records | — |
| Repudiation | No query logging — malicious queries cannot be attributed | — |
| Information Disclosure | Full database dump extracted remotely | — |
| Denial of Service | Automated connection flood exhausts connection pool | — |
| Elevation of Privilege | PostgreSQL SUPERUSER account exploited for OS command execution | — |

**Top 1 Threat:** Unauthorized remote authentication using exposed credentials (Spoofing → Information Disclosure chain).

**Threat Actor:** External opportunistic attacker running automated PostgreSQL credential-stuffing tools against public internet. Shodan lists exposed port 5432 instances within minutes of exposure. The staging DB password is written on the office whiteboard — any visitor, contractor, or WeWork employee has seen it.

**Impact:** Complete exfiltration of customer financial data. Regulatory violation (PCI-DSS, GDPR). IPO-killing event.

---

### Component 2 — SSH Master Key (A-02)

**Configuration:** `nexus_master.pem` pinned in public Slack channel `#dev-ops`. Provides root access to all production servers.

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Any person with Slack access impersonates a legitimate admin | — |
| Tampering | Attacker with key deploys malicious code to production | ✅ **TOP** |
| Repudiation | All SSH sessions share one key — no individual attribution | — |
| Information Disclosure | Key extracted from any compromised Slack account | — |
| Denial of Service | Production servers wiped using key access | — |
| Elevation of Privilege | Key grants root — full privilege from first connection | — |

**Top 1 Threat:** Tampering — any Slack account holder (current or former employee, compromised account) can deploy malicious code, exfiltrate data, or destroy production infrastructure using the shared key.

**Threat Actor:** Malicious insider (disgruntled developer) or external attacker who compromised any Slack account. Slack credentials are frequently targeted in credential-stuffing campaigns. Former employees who were in `#dev-ops` retain the key after offboarding.

**Impact:** Full production compromise. Ransomware deployment. Complete data destruction. No recovery if S3 backup is also deleted (same credentials likely access S3).

---

### Component 3 — Admin Panel (A-05)

**Configuration:** PIN authentication only. CEO insists on PIN `1975` (his birth year).

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Attacker guesses or brute-forces the 4-digit PIN | ✅ **TOP** |
| Tampering | Admin panel used to modify financial parameters or user data | — |
| Repudiation | Single PIN — no individual user attribution | — |
| Information Disclosure | Admin panel exposes full customer and transaction data | — |
| Denial of Service | Admin account locked by repeated failed attempts (if lockout exists) | — |
| Elevation of Privilege | Admin panel provides highest privilege tier | — |

**Top 1 Threat:** Spoofing — the PIN `1975` is a birth year, guessable from LinkedIn/public CEO profile. A 4-digit PIN has 10,000 combinations; automated brute-force completes in under 2 minutes without lockout.

**Threat Actor:** Targeted attacker (competitor, short-seller trying to kill IPO) or journalist with basic OSINT capability.

**Impact:** Full administrative access to financial platform. Fraudulent transactions. Regulatory breach. IPO immediate suspension.

---

### Component 4 — Physical Server Room (A-06)

**Configuration:** Glass-walled meeting room. Biometric lock propped open with fire extinguisher. Delivery personnel observed inside.

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Unauthorized person poses as contractor to access server room | — |
| Tampering | Physical access to servers enables hardware implant or destructive action | ✅ **TOP** |
| Repudiation | No access log — cannot determine who was inside | — |
| Information Disclosure | Direct hardware access bypasses all software controls | — |
| Denial of Service | Physical destruction or disconnection of servers | — |
| Elevation of Privilege | Boot from external media — bypasses OS authentication entirely | — |

**Top 1 Threat:** Tampering — the door is propped open. Any person in the WeWork co-working space has physical access to production servers. A hardware keylogger, network tap, or boot USB takes under 30 seconds to install.

**Threat Actor:** Opportunistic insider threat from co-working space (competitor's employee, journalist, corporate spy). The delivery driver who filmed a TikTok demonstrates this is already occurring.

**Impact:** Persistent undetected compromise. Hardware implant survives OS reinstall. Physical destruction eliminates all data if no off-site backup exists.

---

### Component 5 — Workstations (A-07)

**Configuration:** 80% of MacBooks left unlocked during lunch breaks. Open-plan office with no physical barriers.

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Attacker uses unlocked session as legitimate employee | ✅ **TOP** |
| Tampering | Malicious script deployed via unlocked terminal | — |
| Repudiation | Actions taken on unlocked session attributed to legitimate user | — |
| Information Disclosure | Files, browser sessions, Slack, email visible and exfiltrable | — |
| Denial of Service | Unlocked session used to delete work or corrupt repositories | — |
| Elevation of Privilege | If unlocked session has `nexus_master.pem` loaded in ssh-agent — full production access | — |

**Top 1 Threat:** Spoofing — an unlocked workstation is an authenticated session. Any person who walks past during lunch has full access to that employee's files, Slack (including `#dev-ops` and the SSH key), email, and browser sessions.

**Threat Actor:** WeWork co-worker, visitor, or cleaning staff. No malicious sophistication required — physical proximity and 60 seconds of unsupervised access is sufficient.

**Impact:** Data exfiltration, SSH key extraction, fraudulent communications sent as the legitimate user.

---

### Component 6 — Whiteboard (A-08)

**Configuration:** Wi-Fi Guest password, staging DB password, and CEO Netflix login written in permanent marker on a shared whiteboard.

| STRIDE Category | Threat | Top 1 Threat |
|----------------|--------|-------------|
| Spoofing | Any observer impersonates legitimate network/DB user | — |
| Tampering | Staging DB access used to inject malicious data into production pipeline | — |
| Repudiation | Credential is shared — cannot attribute access | — |
| Information Disclosure | Credentials visible to all office visitors, WeWork staff, delivery personnel | ✅ **TOP** |
| Denial of Service | Staging DB dropped by unauthorized user | — |
| Elevation of Privilege | Staging DB credentials may be reused in production | — |

**Top 1 Threat:** Information Disclosure — credentials written in permanent marker are permanently visible to every person who enters the office, including the delivery driver who was already filming a TikTok inside the building.

**Threat Actor:** Any person with eyes. Zero skill required. This is not a sophisticated threat — it is an immediate, active credential exposure.

**Impact:** Depending on staging/production credential reuse: full database access. At minimum: staging environment compromise used to test attacks before targeting production.

---

## Risk Priority Matrix

| Rank | Asset | Threat | Likelihood | Impact | Priority |
|------|-------|--------|-----------|--------|----------|
| 1 | PostgreSQL DB open to internet (A-01) | Remote unauthorized access | Critical | Critical | **P0 — Fix in 1 hour** |
| 2 | SSH master key in Slack (A-02) | Production server takeover | Critical | Critical | **P0 — Fix in 1 hour** |
| 3 | Admin panel PIN 1975 (A-05) | Brute-force admin access | High | Critical | **P0 — Fix today** |
| 4 | Whiteboard credentials (A-08) | Credential theft | Critical | High | **P0 — Fix now (erase)** |
| 5 | Unlocked workstations (A-07) | Session hijacking | High | High | **P1 — Policy today** |
| 6 | Propped server room door (A-06) | Physical tampering | High | Critical | **P1 — Fix today** |
| 7 | Generic/untracked keycards (A-09) | Unauthorized building access | Medium | High | **P2 — This week** |
| 8 | S3 backup (unverified, A-04) | No recovery capability | High | Critical | **P2 — Verify today** |

---

## Threat Actor Profiles

| Actor | Motivation | Capability | Most Likely Target |
|-------|-----------|-----------|-------------------|
| External opportunistic attacker | Financial gain | Low–Medium (automated tools) | PostgreSQL port 5432, admin panel |
| Corporate spy / competitor | IPO disruption | Medium–High | SSH key, admin panel, database |
| Malicious insider (current/former) | Revenge, financial gain | High (legitimate access) | SSH key, S3 backup deletion |
| Opportunistic physical threat (co-working) | Curiosity, data theft | Low (no technical skill needed) | Unlocked workstations, whiteboard, server room |
| Journalist / short-seller | IPO disruption, story | Low–Medium | Whiteboard credentials, unlocked sessions |
