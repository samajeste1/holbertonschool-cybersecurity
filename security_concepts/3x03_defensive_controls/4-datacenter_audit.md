# Task 4: Physical Security Review — BioHealth Server Room

## Audit Scope

This review assesses the proposed physical security design for BioHealth's new server room against the minimum requirements for a facility processing GDPR-regulated genomic data. Each identified vulnerability is paired with a specific, implementable remediation and an estimated effort/cost level within the 40,000 EUR remediation budget.

---

## Identified Vulnerabilities and Remediations

### Vulnerability 1 — Ground-Floor Window Access

**Finding:** The server room is located on the ground floor with an exterior-facing window. Ground-floor windows represent a direct physical breach vector: an attacker can observe equipment through the window (reconnaissance), break the glass to gain entry, or introduce tools (e.g., USB devices on extension cables) without full entry.

**Regulatory Risk:** GDPR Article 32 requires "appropriate technical and organisational measures" to ensure security of processing. An unprotected ground-floor window on a room containing patient genomic data fails this standard.

**Remediation:**
- Install opaque, shatter-resistant window film (security glazing, minimum EN 356 class P4A) to eliminate visual access and delay forced entry.
- Add steel window bars or an external grille rated to resist manual attack.
- If relocation of the server room to an interior, above-ground-floor space is feasible within the renovation budget, this is the preferred remediation.

**Estimated cost:** 800–2,000 EUR (film + grille). Relocation: project-dependent.

---

### Vulnerability 2 — Dropped/False Ceiling

**Finding:** The server room uses a dropped ceiling without a solid barrier extending to the structural slab above. In facilities with this design, an attacker can remove a ceiling tile in an adjacent room and crawl over the partition wall into the server room, bypassing all door-level access controls entirely.

**Attack vector:** This technique is well-documented in physical penetration testing. The access control on the door is irrelevant if the ceiling provides an unmonitored bypass.

**Remediation:**
- Extend the physical boundary of the server room to the structural ceiling slab using reinforced steel mesh or solid partitioning above the dropped ceiling line.
- Install vibration or intrusion sensors on ceiling tiles within the server room.
- Verify that any cable conduits passing through the ceiling are sealed with fire-rated, tamper-evident materials that cannot be widened without leaving visible evidence.

**Estimated cost:** 3,000–6,000 EUR (structural reinforcement + sensors).

---

### Vulnerability 3 — Default PIN on Access Control Panel

**Finding:** The electronic access control panel protecting the server room door retains its factory-default PIN. Default credentials on security devices are a fundamental vulnerability: they are publicly documented in manufacturer manuals and represent zero effective authentication.

**Regulatory Risk:** The use of default credentials on a system protecting GDPR-regulated data is not a configuration oversight — it is an access control failure. Any person aware of the default code (which is available in the product documentation) has the same access as an authorized user.

**Remediation:**
- Immediately change all default PINs to a randomly generated, minimum 8-digit code.
- Implement individual access credentials per authorized user (individual PIN or badge) rather than a shared code, to enable access logging and accountability.
- Schedule quarterly PIN rotation and document the change in the access control policy.
- Enroll the system in the IT asset inventory and subject it to the same credential management policy as all other access-controlled systems.

**Estimated cost:** 0 EUR (configuration change) to 1,500 EUR if badge reader upgrade is required.

---

### Vulnerability 4 — Exposed Backup Media

**Finding:** Backup tapes or drives are stored in the server room itself, unencrypted and without a locked storage cabinet. This creates two compounding risks:
1. A fire, flood, or other physical event that destroys the server room simultaneously destroys the backups — eliminating recovery capability.
2. A physical intruder who accesses the server room can walk out with a complete copy of all data on a device that fits in a pocket.

**Regulatory Risk:** GDPR requires that personal data be protected against "accidental loss, destruction or damage" (Article 32(1)(c)). Storing unencrypted backups in the same physical location as primary data fails both the availability and confidentiality requirements.

**Remediation:**
- Encrypt all backup media using AES-256 before writing. The encryption key must be stored separately from the media (e.g., in a password manager or HSM, not on a label attached to the tape).
- Store at least one backup copy off-site in a physically separate, access-controlled location (commercial off-site vault service or a secondary BioHealth facility).
- Lock backup media in a physically secured cabinet within the server room when on-site storage is unavoidable for operational reasons.
- Implement a backup media inventory and chain-of-custody log for all media movements.

**Estimated cost:** 500–1,500 EUR (encrypted storage cabinet + off-site media service contract).

---

## Summary Table

| Vulnerability | Attack Vector | Severity | Remediation | Est. Cost |
|--------------|---------------|----------|-------------|-----------|
| Ground-floor window | Physical breach / surveillance | High | Security glazing + grille | 800–2,000 EUR |
| Dropped ceiling bypass | Perimeter bypass (crawl-over) | High | Structural reinforcement + sensors | 3,000–6,000 EUR |
| Default PIN | Credential compromise | Critical | Immediate PIN change + individual credentials | 0–1,500 EUR |
| Exposed unencrypted backup media | Data theft + loss of availability | High | Encryption + off-site storage | 500–1,500 EUR |

**Total estimated remediation cost:** 4,300–11,000 EUR — well within the 40,000 EUR budget constraint, leaving capacity for technical and administrative remediation items from the Gap Analysis.
