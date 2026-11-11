# Threat Model — Meridian Federal Bank

## Framework Declaration

STRIDE

## Rationale

The audience is the bank's internal architecture team, and the deliverable has to become engineering decisions during a live migration, not a board vote. The engagement is scoped to the six-week dual-running window between the legacy mainframe and the hybrid AWS / on-premises estate, which is an architecture decomposition problem: new trust boundaries appear while both cores are still authoritative. The migration architecture diagram is the primary workspace artifact, and the Rules of Engagement draw a hard line around what may be modeled. STRIDE maps each of those elements to a spoofing, tampering, repudiation, information-disclosure, denial-of-service, or elevation threat the engineers can assign. PASTA would answer a launch-or-delay question this brief does not ask. ATT&CK would catalogue adversary procedures before the transition-state controls exist to map them onto.

## Framework Selection Feedback

STRIDE is strong here because the dual-running diagram already names the elements that change: mainframe, cloud landing zone, replication path, and the channel that must choose a core. Its blind spot is regulatory consequence. SOX, GLBA, and OCC explain why a control matters to an examiner, and STRIDE will not rank a threat by examination risk unless the architecture team adds that ranking after the matrix.

## Threat Model

In scope: the US core, the hybrid AWS / on-premises landing zone, the replication path used during dual-running, customer channels that can reach either core, and the identity bridge between them. The Luxembourg subsidiary is outside this model.

| Element | S | T | R | I | D | E | Priority note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Legacy mainframe core | Shared service accounts reused from branch operations can still authenticate as a system user. | Unsynchronized batch updates during dual-run can alter balances the cloud core has already accepted. | Mainframe job logs and cloud API logs are separate, so a change cannot be tied to one actor. | Account and transaction data sit in a core that was not built for the new channel volume. | A stalled batch window stops posting for branches still bound to the mainframe. | A migrated operator role may retain mainframe privileges that the new IAM role was meant to replace. | Highest. Two cores, one customer. |
| Replication path (mainframe ↔ AWS) | A job that presents the mainframe's identity to AWS, or the reverse, is trusted because it sits on the "internal" path. | Records can be altered in flight if the pipe is not authenticated end to end. | Each side logs the batch, neither logs the hop, so a bad sync has no single trail. | The pipe carries full account records, not the minimum the other core needs. | Saturation or a stuck cursor halts both cores' view of the ledger. | The replication principal is often an admin-equivalent service account. | Highest. This path did not exist before the migration. |
| AWS landing zone (hybrid) | Cloud roles can be assumed with credentials issued for the on-premises bridge. | Infrastructure-as-code and console changes can diverge during the six weeks. | CloudTrail and the on-premises audit log are not correlated. | Mis-scoped storage or a snapshot can expose customer financial data outside the core. | A bad deploy in the landing zone takes the new core down while the old core is already being drained. | A migration role left attached after cutover is standing privilege. | High. |
| Customer channel (online / mobile / branch front end) | A session minted against one core may be replayed against the other during dual-run. | Transaction messages can be modified if the channel still speaks a legacy protocol on one path. | The customer cannot be shown which core booked the transaction. | Account data is returned by whichever core the channel reached. | Failover that is not explicit becomes an outage when one core is drained. | A channel service account that can post to both cores exceeds what either core's users can do. | High. |
| Identity bridge | Legacy credentials and cloud roles represent the same employee with different assurance. | Group membership can be edited on one side and not the other. | Access reviews cannot say which directory authorized a given call. | The bridge copies HR and entitlement data into both directories. | Directory failure locks operators out of the core they still need. | An entitlement that meant "read" on the mainframe can mean "administer" in IAM. | High. |

## Identified Findings

1. **Dual-authoritative ledger.** During the six weeks, both the mainframe and the AWS core can accept a posting. STRIDE marks this first as tampering and repudiation on the replication path and the channel: a transaction can be applied twice or applied once and logged twice, and neither log is the system of record. Priority follows from the element that did not exist before the migration.

2. **Replication principal is over-privileged.** The job that moves account records is, in STRIDE terms, an elevation-of-privilege and information-disclosure problem on the same element. It can read the full ledger and it can write. A compromised sync account is a compromise of both cores.

3. **Identity is split.** Spoofing and elevation on the identity bridge: the same person or service holds a legacy credential and a cloud role that were not designed together. Examiners will treat that as an access-control failure. The architecture team can close it by naming one directory as authoritative before cutover, not after.

4. **Channel failover is implicit.** Denial of service and spoofing on the customer channel: if the path to a core is chosen by timeout rather than by a routed product flag, customers hit whichever core is still up, including one that should already be read-only.
