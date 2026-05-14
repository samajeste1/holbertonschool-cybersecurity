# ApexVault Security Design Document (SDD)

**Classification:** Confidential — Internal Use Only
**Version:** 1.0
**Prepared by:** DefendSec Consulting
**Client:** ApexFin Global

---

## Executive Summary

ApexVault is a zero-trust, hyper-secure storage platform designed for VIP client data at ApexFin Global. The core security philosophy is simple: **trust nothing, verify everything, and assume breach**.

Every design decision follows three non-negotiable principles:

1. **No password, no exception** — credentials that can be stolen, phished, or guessed are banned.
2. **Least privilege is absolute** — even system administrators cannot read client data, only manage infrastructure.
3. **Logs are immutable evidence** — audit trails must survive any compromise, including insider attacks.

This document defines the technical architecture that enforces these principles at the hardware, OS, and application layers.

---

## 1. Authentication Strategy

### Selected Technology: FIDO2 / WebAuthn with Hardware Security Keys (YubiKey 5 Series or equivalent)

Each VIP client and system operator is issued a FIDO2-compliant hardware token. Authentication requires physical possession of the device plus a local biometric (fingerprint) or PIN verified on-device — never transmitted over the network.

### Justification

| Vector | Password / SMS OTP | FIDO2 Hardware Token |
|--------|-------------------|----------------------|
| Phishing | Fully vulnerable — attacker captures credentials via fake login page | Immune — the key signs a challenge bound to the exact origin domain; a fake site gets a signature for a different origin, which the server rejects |
| Credential stuffing | Vulnerable — reused passwords work across sites | Not applicable — no shared secret exists on the server |
| SIM-swap (SMS OTP) | Fully vulnerable — attacker redirects SMS to their device | Not applicable — no phone number involved |
| Man-in-the-middle | Vulnerable — credentials intercepted in transit | Immune — the private key never leaves the hardware token |
| Server-side breach | Password hashes stolen and cracked | Nothing to steal — server stores only a public key |

FIDO2 achieves **un-phishability** by cryptographic origin binding: the authenticator includes the relying party ID (e.g., `apexvault.apexfin.com`) in the signed assertion. An attacker who clones the login page at a different domain cannot produce a valid signature for the legitimate server.

---

## 2. Authorization Model

### Model Selected: MAC (Mandatory Access Control) enforced via SELinux + Client-Side Encryption

A hybrid approach is required because no single model is sufficient:

- **MAC via SELinux** enforces kernel-level access controls that cannot be bypassed by root.
- **Client-Side Encryption (CSE)** ensures that even if OS-level controls are circumvented, the data remains ciphertext without the client's key.

### Admin Restriction — Technical Block on Root Access to Client Files

The Root user problem is solved through three complementary layers:

**Layer 1 — Client-Side Encryption (CSE)**
Client data is encrypted on the client device before transmission, using a key derived from the client's FIDO2 hardware token. The server stores only ciphertext. The decryption key never exists on the server — a SysAdmin with full root access sees only encrypted blobs, not plaintext.

**Layer 2 — Hardware Security Module (HSM)**
Key derivation and wrapping operations occur inside a FIPS 140-2 Level 3 HSM (e.g., Thales Luna or AWS CloudHSM). The HSM enforces access policies that block administrative users from extracting raw keys. Root on the OS cannot issue commands to the HSM that would expose client keys.

**Layer 3 — SELinux Mandatory Access Control**
SELinux policies assign a dedicated sensitivity label (e.g., `client_data_t`) to all vault storage paths. The SysAdmin role is confined to a domain (`sysadmin_t`) that has `manage` and `relabel` permissions on the server processes, but explicitly **no** `read` or `write` permissions on `client_data_t`. This policy is enforced by the kernel — the root UID does not override it.

**Role Matrix:**

| Role | Manage Server | Read Client Data | Modify Client Data | Access HSM Keys |
|------|:---:|:---:|:---:|:---:|
| VIP Client | No | Yes (own data only) | Yes (own data only) | No |
| SysAdmin | Yes | **No** | **No** | **No** |
| Security Auditor | No | No | No | No |
| HSM Officer | No | No | No | Partial (audit only) |

---

## 3. Accounting Architecture

### Storage Location: Centralized, Append-Only, Off-Site SIEM with Write-Once Storage

Logs are shipped in real time from ApexVault servers to an isolated, dedicated SIEM cluster (e.g., Splunk or Elasticsearch) that:

- Resides on a **separate network segment** with no inbound connections from the production environment.
- Is reachable only via a **one-way log forwarding agent** (syslog-ng or Fluentd) — the production server pushes logs out but cannot query or modify the SIEM.
- Stores all events on **WORM (Write Once Read Many) storage** (e.g., AWS S3 Object Lock in Compliance Mode, or NetApp SnapLock) with a minimum 1-year retention lock that cannot be shortened even by the storage administrator.

### Integrity Mechanism: Cryptographic Hash Chaining + External Timestamping

**Hash Chaining**
Each log entry includes the SHA-256 hash of the previous entry, forming a chain. Any deletion or modification of a record breaks the chain, producing an immediately detectable integrity violation — identical to the structure of a blockchain ledger.

```
Entry N:  { timestamp, event_data, hash(Entry N-1) } → SHA-256 → hash(Entry N)
Entry N+1:{ timestamp, event_data, hash(Entry N)   } → SHA-256 → hash(Entry N+1)
```

**RFC 3161 Trusted Timestamping**
Every log batch is submitted to a qualified Trust Service Provider (TSP) that issues a cryptographically signed timestamp token. This provides **non-repudiation** with legal standing: it is mathematically provable that a log entry existed at a specific time and has not been altered since.

**Result — The Bob Problem is Solved**
Even a compromised root account on the production server cannot alter the audit trail:

- The SIEM is unreachable from production (no write-back path).
- WORM storage rejects any delete or overwrite command, regardless of the requesting identity.
- Hash chaining makes any gap in the chain self-evident to auditors.
- RFC 3161 timestamps provide court-admissible proof of log authenticity.

---

## Summary Table

| Security Pillar | Technology | Guarantee |
|----------------|-----------|-----------|
| Authentication | FIDO2 + Hardware Token + Biometric | Un-phishable, no shared secret |
| Authorization | CSE + HSM + SELinux MAC | Root cannot read client data |
| Accounting | WORM SIEM + Hash Chaining + RFC 3161 | Logs cannot be deleted or forged |
