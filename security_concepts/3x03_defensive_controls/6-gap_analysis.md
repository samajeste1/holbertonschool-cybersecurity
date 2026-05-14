# Task 6: Gap Analysis — BioHealth Inc. vs. CNIL Minimum Requirements

## Reference Framework

This gap analysis maps BioHealth's current control posture against the minimum baseline required by the CNIL notice, cross-referenced with ISO 27001 Annex A controls and GDPR Article 32 technical and organisational measures.

---

## Gap Analysis Table

| # | Finding | Current State | Required State | Remediation Action | Owner | Deadline | Est. Cost |
|---|---------|---------------|----------------|--------------------|-------|----------|-----------|
| GAP-01 | No Acceptable Use Policy | No written AUP exists. No prohibition on credential sharing, unauthorized software, or misuse of resources. | Documented AUP covering prohibited activities, credential management, and data handling, signed by all personnel. | Draft and publish AUP (template: BIO-POL-AUP-001). Collect signed acknowledgments from all staff. | CISO + HR Director | Day 15 | 0 EUR (internal effort) |
| GAP-02 | Shared and unrevoked credentials | Shared credentials in active use. Former employee credentials not revoked after departure. | Individual, named credentials for all users. Credential revocation within 4 hours of departure. | Audit all active accounts. Disable all shared/unattributed accounts. Implement offboarding SOP with IT notification. | IT Security + HR | Day 10 | 0 EUR |
| GAP-03 | No Multi-Factor Authentication | Single-factor (password only) authentication on all systems including the genomic research database. | MFA required for all remote access and access to systems containing personal data (GDPR Art. 32). | Deploy MFA via authenticator app (e.g., Microsoft Authenticator or Google Authenticator) for all user accounts. Priority: database and remote access. | IT Security | Day 30 | 500–2,000 EUR |
| GAP-04 | No network segmentation | Flat network architecture. All systems (MRI, workstations, research database, internet) on the same segment. | Segmented network with isolated VLANs for clinical devices, research data, and corporate LAN. | Configure managed switches with VLANs. Implement ACL deny-by-default between segments. Priority: MRI isolation (GAP-04a), database isolation (GAP-04b). | IT Security | Day 45 | 1,000–3,000 EUR |
| GAP-05 | No encryption of genomic data at rest | Raw genomic sequencing files stored in plaintext on the research database server. | Sensitive personal data (especially special category data under GDPR Art. 9) must be encrypted at rest. | Enable AES-256 encryption on the database storage volume (e.g., AWS EBS encryption if on AWS, or VeraCrypt for on-premises). Key management via AWS KMS or equivalent. | IT Security | Day 45 | 0–1,000 EUR (cloud-native encryption may be zero cost) |
| GAP-06 | No audit logging on database access | No record of who accessed which genomic records, when, or what queries were executed. Direct cause of inability to detect the CNIL-triggering incident. | Complete, tamper-evident audit log of all access to systems containing personal data (GDPR Art. 30 records of processing). | Enable database audit logging (PostgreSQL pgaudit, MySQL General Log, or AWS CloudTrail for RDS). Ship logs to centralized, write-protected log storage. | IT Security | Day 20 | 0–500 EUR |
| GAP-07 | No physical access log on server room | Padlock only. No record of who entered the server room or when. | Access log for all entry to facilities housing personal data processing equipment. | Replace padlock with electronic badge reader + access log. Minimum: install a log book with mandatory signed entry until badge system is deployed. | Facilities + IT Security | Day 30 | 1,500–3,000 EUR |
| GAP-08 | No Security Awareness Training | No formal security training program. Staff unaware of credential sharing risks, phishing, or data handling obligations. | Annual security awareness training for all personnel with access to personal data. | Procure and deploy an online security awareness training platform (e.g., KnowBe4, Proofpoint). First training cycle covering credentials, phishing, and data handling. | CISO + HR | Day 60 | 1,000–3,000 EUR/year |
| GAP-09 | No Incident Response Plan | No documented procedure for responding to a data breach or security incident. GDPR Art. 33 requires notification to supervisory authority within 72 hours of becoming aware of a breach. | Documented Incident Response Plan including breach notification procedures, escalation contacts, and evidence preservation steps. | Draft IRP using NIST SP 800-61 template. Designate GDPR Data Protection Officer or responsible contact. Conduct tabletop exercise. | CISO + Legal | Day 45 | 0 EUR (internal effort) |
| GAP-10 | Unencrypted backup media (on-site only) | Backup tapes/drives stored unencrypted in the server room. No off-site copy. | Encrypted backups stored in geographically separate location. Backup integrity tested regularly. | Encrypt all backup media (AES-256). Contract off-site backup storage. Implement 3-2-1 backup rule. | IT Security | Day 30 | 500–1,500 EUR |

---

## Compensating Controls (Where Full Remediation Not Feasible in 90 Days)

| Gap | Compensating Control | Justification |
|-----|---------------------|---------------|
| GAP-04a — MRI Windows XP (no patch feasible) | Hard VLAN isolation + ACL deny-all + IDS monitoring on boundary (see 5-compensating_controls.md) | Device cannot be patched or replaced. Network isolation eliminates remote exploitability. Accepted by CNIL as interim measure with documented review timeline. |

---

## Remediation Budget Summary

| Category | Items | Estimated Cost |
|----------|-------|----------------|
| Administrative | GAP-01, GAP-02, GAP-08, GAP-09 | 1,000–3,000 EUR |
| Technical | GAP-03, GAP-04, GAP-05, GAP-06, GAP-10 | 2,000–7,500 EUR |
| Physical | GAP-07 + datacenter audit items | 5,800–14,500 EUR |
| **Total** | | **8,800–25,000 EUR** |

All remediations are achievable within the 40,000 EUR budget constraint with margin for contingency.

---

## 90-Day Remediation Roadmap

| Week | Priority Actions |
|------|-----------------|
| 1–2 | Revoke all shared/unrevoked credentials (GAP-02). Publish AUP (GAP-01). Enable database audit logging (GAP-06). |
| 3–4 | Deploy MFA on all systems (GAP-03). Enable encryption at rest (GAP-05). Encrypt and off-site backups (GAP-10). |
| 5–6 | Implement VLAN segmentation including MRI isolation (GAP-04). Install server room badge access (GAP-07). |
| 7–10 | Deploy security awareness training (GAP-08). Draft and test Incident Response Plan (GAP-09). |
| 11–13 | Conduct internal audit against this gap analysis. Prepare CNIL submission with evidence of remediation. |
