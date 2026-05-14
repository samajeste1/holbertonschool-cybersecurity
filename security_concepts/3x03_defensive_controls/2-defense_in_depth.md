# Task 2: Defense in Depth — USB Keylogger Incident Reconstruction

## Incident Summary

Last quarter, an attacker planted a USB-based hardware keylogger on a BioHealth workstation. The device captured employee credentials, which were subsequently used to authenticate remotely to the genomic research database. The CTO's assessment — "the antivirus failed" — is factually incomplete. The antivirus did fail. So did every other layer that should have stopped this attack before and after that point.

## Attack Chain Reconstruction

### Phase 1 — Physical Entry

**What happened:** The attacker gained physical access to the office space and connected a hardware keylogger to a workstation USB port.

**Control that failed:** *Physical — Preventive*
- No visitor access log or sign-in procedure.
- No physical access control on the workstation area (badge reader, mantrap, or escorted-visitor policy).
- No asset port control policy (USB ports were not disabled or physically blocked).

**What would have stopped it:** A Physical Preventive control — locked workstation area with badge access and a visitor escort policy — would have denied the attacker physical proximity to the hardware.

---

### Phase 2 — Keylogger Installation

**What happened:** The attacker plugged a hardware keylogger into the workstation's USB port. Because it is a hardware device, it operates below the OS layer and is invisible to antivirus software.

**Controls that failed:** *Technical — Preventive + Administrative — Preventive*
- No USB port disable policy enforced via Group Policy or endpoint management.
- No physical USB port blockers deployed on workstations.
- No Acceptable Use Policy prohibiting unauthorized hardware attachment.

**What would have stopped it:** Disabling USB ports via endpoint management (Technical Preventive) or a written prohibition on unauthorized hardware enforced through disciplinary policy (Administrative Preventive) would have prevented or deterred installation.

---

### Phase 3 — Credential Capture

**What happened:** The keylogger silently captured username and password credentials typed by the employee over days or weeks.

**Controls that failed:** *Technical — Preventive*
- No Multi-Factor Authentication (MFA) on internal systems. A captured password alone was sufficient to authenticate.
- Shared credentials were in use, meaning one capture compromised multiple accounts.

**What would have stopped it:** MFA (Technical Preventive) would have rendered the captured password alone insufficient for authentication — a stolen credential without the second factor does not produce access.

---

### Phase 4 — Remote Authentication to Database

**What happened:** The attacker used the captured credentials to authenticate remotely to the genomic research database from an external location.

**Controls that failed:** *Technical — Detective + Technical — Preventive*
- No anomaly detection or SIEM alert for authentication from a new IP/geolocation outside business hours.
- No network segmentation isolating the database from the internet-facing perimeter.
- No VPN requirement for remote database access.
- No account lockout or impossible-travel detection.

**What would have stopped it:** Network segmentation (Technical Preventive) would have blocked direct external access to the database. Anomaly-based authentication monitoring (Technical Detective) would have flagged the login within minutes.

---

### Phase 5 — Data Exfiltration

**What happened:** The attacker accessed and exfiltrated raw genomic sequencing data from the research database.

**Controls that failed:** *Technical — Detective + Technical — Preventive*
- No Data Loss Prevention (DLP) tool to detect or block bulk data transfers.
- No encryption on data at rest — exported data was immediately readable.
- No audit logging on database queries that would have generated an alert on a mass SELECT operation.

**What would have stopped it:** DLP (Technical Detective/Preventive) would have detected the anomalous data volume. Encryption at rest (Technical Preventive) would have ensured exfiltrated data was useless without the decryption key. Database activity monitoring (Technical Detective) would have logged and alerted on the query pattern.

---

## Defense in Depth Summary Table

| Attack Phase | Layer Bypassed | Missing Control | Function |
|-------------|----------------|-----------------|----------|
| Physical entry | Physical | Badge access, visitor policy | Preventive |
| USB installation | Technical + Administrative | USB port disable, AUP | Preventive |
| Credential capture | Technical | MFA, no shared credentials | Preventive |
| Remote authentication | Technical | Network segmentation, anomaly detection | Preventive + Detective |
| Data exfiltration | Technical | DLP, encryption at rest, DB audit logs | Detective + Preventive |

## Conclusion

The antivirus did not fail in isolation. A hardware keylogger is specifically designed to operate below the software layer — no antivirus product detects a physical USB device passively logging keystrokes. The attack succeeded because **every layer** that should have independently stopped it was absent or incomplete. This is precisely the failure mode that Defense in Depth is designed to prevent: when Layer N fails, Layer N+1 contains the damage. BioHealth had no Layer N+1.
