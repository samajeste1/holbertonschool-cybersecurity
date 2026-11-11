# Threat Model — Helix Aerospace Systems

## Framework Declaration

MITRE ATT&CK

## Rationale

The BSI contract, and the DGA negotiation behind it, do not ask whether Helix is "secure." They require Helix to show resilience against named adversary clusters and against documented techniques. The business-context document states the commercial stake, about half of forecast revenue, and it points at those clusters: one state-aligned cluster commonly attributed to Russia, and one financially motivated cluster active against European defense suppliers. The BSI unclassified threat note is the operational specification of that requirement, including one technique marked as emerging and not yet in the published ATT&CK matrices. ATT&CK is the only lens that maps a control to a technique an auditor or a procurement officer can look up. STRIDE would decompose the tenant architecture without answering the contract. PASTA would restate the revenue risk the CISO already briefed.

## Framework Selection Feedback

ATT&CK is strong for Helix because the downstream readers, BSI auditors, DGA procurement, and NATO interoperability reviewers, already speak in techniques and will reject a report that cannot be traced to the clusters in the contract. Its blind spot is coverage. The published Enterprise matrix does not contain the italicized emerging technique in the BSI note. Treating the matrix as complete would leave a contractual TTP unmodeled. That technique is carried below as emerging, not forced into a nearby published ID.

## Threat Model

System under test. Multi-tenant SaaS for aerospace and defense operational analytics. European-sovereign hosting (OVHcloud and Deutsche Telekom T-Systems). BSI C5-attested. Per-client isolation is the control the contract actually relies on. No US government clients, by Helix's own positioning. Named employees in the stakeholder profiles are not adversaries and are not modeled.

Adversary A. State-aligned cluster, commonly attributed to Russia, as named in the contract excerpts and the BSI note. Objective consistent with that class of actor: durable access to a defense supplier's tenant, collection of operational data, and reuse of a trusted integration.

Adversary B. Financially motivated cluster active against European defense suppliers, as named in the same documents. Objective: access that can be turned into disruption or extortion of a supplier whose contracts cannot tolerate downtime.

Published techniques these clusters make relevant to this architecture. IDs are the Enterprise matrix techniques a reviewer should be able to test. They are not a claim that the BSI note uses only this list. The note remains the source of truth for the contractual set.

| Technique | ID | Where it lands on Helix | Which cluster | What resilience has to mean |
| --- | --- | --- | --- | --- |
| Exploit public-facing application | T1190 | The shared analytics edge in front of every tenant. | A and B | A flaw in the edge is not one client's incident. Isolation has to hold behind it. |
| Valid accounts | T1078 | Tenant administrator and break-glass roles. | A and B | A stolen client admin must not read another tenant. Provider staff access must be attributable. |
| External remote services | T1133 | Administrative access to the sovereign hosting environment. | A | Remote admin paths are in the same trust decision as the application. |
| Trusted relationship | T1199 | A client integration, a support channel, or a shared pipeline. | A | A supplier relationship must not cross the tenant boundary. |
| Data from cloud storage | T1530 | Per-tenant object storage and analytics exports. | A | Storage policy is tenant-scoped. A platform role is not a wildcard. |
| Transfer to cloud account | T1537 | Copy of a tenant's operational data into an account the client does not control. | A | Egress of tenant data is logged per tenant and alerted. |
| Data encrypted for impact | T1486 | Tenant stores and backups. | B | Encryption of one tenant's volume must not be a platform-wide event. Backups are isolated and restorable. |
| Inhibit system recovery | T1490 | Backup and snapshot administration. | B | Recovery roles are separate from the roles an intrusion is likely to steal. |

Emerging technique. The BSI unclassified threat note flags one TTP in italics as emerging and not yet in the published matrices. It is recorded here as **EMERGING — not an ATT&CK ID**. It is not given a nearby published number. Until the note's wording is confirmed against the PDF, the contractual claim is: Helix cannot yet show a detection or a control mapped to that TTP, and C5 attestation does not fill the gap. Sovereign hosting does not either. OVHcloud and T-Systems change where the workloads sit. They do not implement tenant isolation against T1078 or T1199.

What this model refuses. Stakeholder profiles name people. Those names are not insider-threat cases. Profiling an employee is not threat modeling, and it is the wrong move under European employment rules at this stage of the engagement. Insider risk, if Helix wants it, is a separate, lawful exercise. It is not implied by the BSI note.

## Identified Findings

1. **The contractual claim is a technique claim.** Helix has to show that tenant isolation still holds when Adversary A uses a valid account or a trusted relationship, and when Adversary B tries to encrypt or sabotage recovery. C5 and sovereign hosting are not that demonstration.

2. **The shared edge is a cross-tenant initial-access path (T1190).** A single public flaw in front of a multi-tenant product is a resilience failure for every client named in the BSI and DGA conversations.

3. **Recovery is in the financially motivated cluster's path (T1486, T1490).** Backups and snapshot rights that sit with day-to-day administration will not support the resilience statement those contracts expect.

4. **One required TTP is outside the published matrix.** The italicized emerging technique in the BSI note has no ATT&CK ID. Leaving it off the model would make the report look complete and the contract look covered. It is not covered.
