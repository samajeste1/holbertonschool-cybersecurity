# Vanguard Security: Threat Modeling Engagement Report
## Client: Helix Aerospace Systems

**Prepared by:** samajeste1, Junior Consultant
**Date:** 12 November 2026
**Distribution:** Helix CISO (with downstream BSI / DGA review)

## 1. Executive Summary

Helix's BSI contract and the pending DGA negotiation ask for a resilience claim against two named adversary clusters, not for a general opinion of the product. Those clusters are a state-aligned cluster commonly attributed to Russia and a financially motivated cluster active against European defense suppliers. The claim is only as good as the techniques it can be traced to. Tenant isolation on OVHcloud and T-Systems, and the existing BSI C5 attestation, do not by themselves answer valid-account access, a trusted supplier path, or destruction of recovery. One technique in the BSI threat note is explicitly emerging and is not in the published ATT&CK matrices. It is reported as a gap, not folded into a nearby ID. People named in the stakeholder pack are not part of this model.

## 2. Engagement Context

Helix is a Munich SaaS company, about 120 staff, selling multi-tenant operational analytics to aerospace and defense clients. Hosting is European-sovereign, OVHcloud and Deutsche Telekom T-Systems, and the platform is BSI C5-attested. Helix has no US government clients by choice. The combined BSI and projected DGA value is about half of forecast revenue. The business-context document and the contract excerpts name the clusters. The BSI unclassified threat note is the document that turns those names into techniques, including one marked emerging.

## 3. Framework Choice and Rationale

MITRE ATT&CK. The BSI threat note is the operational source for this engagement, and the contract excerpts in the business-context document commit Helix to resist the clusters that note describes. Downstream readers at BSI, on the DGA side, and in NATO interoperability reviews expect a technique mapping they can audit. A decomposition of the cloud diagram would not state which adversary capability remains untested. A business-risk essay would restate the revenue figure the CISO already has.

## 4. Threat Model

Two clusters, taken from the contract excerpts and the BSI note. No employee from the stakeholder profiles is an actor in this model.

| Technique | ID | Where it lands | Cluster | Resilience statement |
| --- | --- | --- | --- | --- |
| Exploit public-facing application | T1190 | Shared analytics edge | A and B | Isolation must survive a flaw in the common front door. |
| Valid accounts | T1078 | Tenant admin and break-glass | A and B | One client's admin must not read another tenant. Staff access must be attributable. |
| External remote services | T1133 | Hosting administration | A | Remote admin is in the same decision as the application. |
| Trusted relationship | T1199 | Client integration or shared pipeline | A | A supplier path must not cross tenants. |
| Data from cloud storage | T1530 | Per-tenant stores and exports | A | A platform role is not a wildcard over tenant buckets. |
| Transfer to cloud account | T1537 | Copy out of the tenant | A | Egress is logged and alerted per tenant. |
| Data encrypted for impact | T1486 | Tenant stores and backups | B | Encrypting one tenant is not a platform event. |
| Inhibit system recovery | T1490 | Backup administration | B | Recovery rights are not the rights an intrusion is likely to hold. |

**EMERGING — no ATT&CK ID.** The BSI note italicizes one TTP as emerging and not yet published in the matrices. It is in this model as an open contractual item. It is not mapped to a neighboring technique to make the table look finished. C5 attestation and the choice of OVHcloud or T-Systems do not close it.

## 5. Recommendations and Prioritization

1. **Test tenant isolation against T1078 and T1199 before the BSI operational phase.** A stolen client administrator and a compromised integration are the state-aligned cluster's realistic paths into a multi-tenant product. The test is a second tenant that remains unreadable. Sovereign hosting is not the control under test.
2. **Treat the shared edge as a cross-tenant T1190 finding until proven otherwise.** Patch priority and logging on that edge are contractual, because every tenant sits behind it.
3. **Separate recovery administration from day-to-day administration (T1486, T1490).** The financially motivated cluster's aim is to make a defense supplier unable to restore. Backup roles, snapshot deletion, and the break-glass path need a different set of credentials and an alert that is not owned by those credentials.
4. **Write the emerging TTP into the resilience statement as uncovered.** Tell BSI and the DGA negotiation that this item has no published technique ID yet, what the note says it is, and what detection would have to see. Do not claim coverage the matrix does not provide.

## 6. Limitations and Uncertainty

The published Enterprise matrix is the wrong place to hide the italicized TTP. This report marks it emerging and stops. The exact wording lives in the BSI PDF. If the note's description is narrower or broader than a reader infers from "emerging," the detection requirement changes with that wording, not with this table.

Technique IDs in section 4 are the published techniques that match the two clusters as the contract and the note characterize them. They are the review set. They are not a substitute for the note's own list where the note is more specific.

This model does not assess OVHcloud's or T-Systems' internal operations, and it does not assess other tenants' organizations. It assesses Helix's isolation, administration, and recovery against the named clusters. National attribution of Adversary A is used only as the contract uses it ("commonly attributed"). It is not an intelligence finding by Vanguard.

Named individuals in the stakeholder profile were read and then left out. Profiling them as insiders would be methodologically wrong at this stage and inappropriate in a European employment context. Nothing in the BSI note requires it.

## 7. Appendix: Sourced Findings

- The two clusters are sourced from the contract excerpts in the business-context document and from the BSI unclassified threat note, which this engagement treats as the operational specification.
- T1190, T1078, T1133, T1199, T1530, T1537, T1486, and T1490 are sourced from the published MITRE ATT&CK Enterprise matrix, selected because they are the techniques those cluster descriptions put on a multi-tenant sovereign SaaS platform. They should be reconciled with the note's own citations before the report is sent to BSI.
- **Emerging TTP, status explicit.** Sourced from the italicized passage in the BSI unclassified threat note ("emerging, not yet in published ATT&CK matrices"). No technique ID is assigned. No hidden document flag is claimed. Metadata inspection of that PDF was not available in the local working set. The note, not this appendix, remains the citation a BSI reviewer should be shown.
