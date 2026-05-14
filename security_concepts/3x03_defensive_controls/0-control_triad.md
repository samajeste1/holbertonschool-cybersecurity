# Task 0: The Control Triad

## BioHealth Inc. — Control Inventory

The three categories of security controls are **Administrative**, **Technical**, and **Physical**. The table below classifies each existing BioHealth measure and identifies its status.

| Control | Category | Status |
|---------|----------|--------|
| AWS Security Groups (firewall rules) | Technical | Partial — network perimeter only, no internal segmentation |
| Antivirus software on workstations | Technical | Present |
| Server room padlock | Physical | Partial — single-factor, no access log |
| HR onboarding/offboarding process | Administrative | Partial — no formal credential revocation procedure |
| No written security policy | Administrative | Absent |
| No security awareness training | Administrative | Absent |
| No physical access log | Physical | Absent |
| No intrusion detection system | Technical | Absent |
| No data loss prevention (DLP) | Technical | Absent |
| No encryption on genomic data at rest | Technical | Absent |

### Key Finding

BioHealth's security posture is composed almost entirely of partial Technical controls. Administrative controls — the governance layer that defines *who* may do *what*, under *which* conditions — are entirely absent. Physical controls reduce to a single padlock with no audit trail. This structure is not a security program; it is a collection of tools with no governance framework connecting them.

**Root Cause of the CNIL Incident:** The shared credentials that were never revoked after employee departure represent a failure of the Administrative control category (specifically: no offboarding procedure, no Acceptable Use Policy, no Identity and Access Management policy). No Technical control can compensate for an absent Administrative process that governs credential lifecycle.
