# Vanguard Security: Threat Modeling Engagement Report
## Client: Meridian Federal Bank

**Prepared by:** samajeste1, Junior Consultant
**Date:** 12 November 2026
**Distribution:** Meridian internal architecture team

## 1. Executive Summary

The risk this engagement was asked to find sits in the six-week dual-running window, not in the target architecture. While the legacy mainframe and the hybrid AWS core can both post, the replication path and the customer channel are new trust boundaries with no single system of record and no single directory. The architecture team should treat the sync principal, the identity bridge, and explicit core routing as migration defects, and should close them before either core is drained. This is a STRIDE decomposition of the in-scope US estate. It is not a board paper and it does not model the Luxembourg subsidiary.

## 2. Engagement Context

Meridian is a federally supervised regional bank, mid-migration from a mainframe to a hybrid AWS and on-premises estate. Vanguard was engaged to identify the risks the transition state introduces, for the engineers who have to change that state. The useful question is which new element can spoof, alter, hide, leak, stop, or over-privilege a posting while both cores are still live.

## 3. Framework Choice and Rationale

STRIDE. The audience is the internal architecture team, and the workspace artifact that drives the work is the migration architecture diagram, not a strategic "whether" question. The Rules of Engagement then restrict which of those elements may be modeled. STRIDE is the lens that turns those two documents into tickets. A business-impact process would bury the dual-run defects under a regulatory narrative the engineers already know. An adversary-technique catalogue would name procedures before the transition controls those procedures have to be mapped to exist.

## 4. Threat Model

| Element | S | T | R | I | D | E | Priority note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Legacy mainframe core | Reused service accounts still authenticate. | Batch updates can diverge from the cloud ledger. | Job logs and API logs do not join. | Full account data remains in the old core. | A stalled batch stops branch posting. | An old operator role outlives its cloud equivalent. | Two cores, one customer. |
| Replication path | The sync job is trusted because it is "internal." | Records can change in flight. | Neither side logs the hop. | The pipe carries full ledgers. | A stuck cursor blinds both cores. | The sync principal can read and write both sides. | Did not exist before migration. |
| AWS landing zone | On-premises credentials can assume cloud roles. | Console and code can diverge for six weeks. | CloudTrail and the mainframe audit are separate. | A snapshot or bucket can leave the core. | A bad deploy drops the new core during drain. | A migration role survives cutover. | High. |
| Customer channel | A session for one core can be replayed to the other. | A legacy message path can be modified. | The customer cannot see which core booked. | Whichever core answers returns account data. | Implicit failover is an outage. | One service account can post to both cores. | High. |
| Identity bridge | One employee, two assurances. | Entitlements edit on one side only. | No single authorization record. | HR and entitlement data are copied twice. | Directory loss locks the remaining core. | "Read" on the mainframe may be "admin" in IAM. | High. |

Findings, in the order STRIDE forces:

1. Both cores can post. Tampering and repudiation on the replication path and the channel.
2. The replication principal can read and write the ledger. Elevation and disclosure on one element.
3. The identity bridge duplicates authority. Spoofing and elevation.
4. Channel routing follows timeout, not a product flag. Spoofing and denial of service.

## 5. Recommendations and Prioritization

1. **Make one core authoritative for each product before the drain starts.** The other core is read-only for that product. Reject a second posting in the application, not only in a reconciliation report the next morning.
2. **Replace the replication principal.** Mutual authentication on the pipe, a dedicated role that can write only the sync schema, and a log line on each hop that carries the same batch id. Remove the role when dual-run ends.
3. **Pick one directory as authoritative now.** Freeze entitlement changes on the other side. Map mainframe privileges to cloud roles explicitly. Do not leave "equivalent" groups to operator judgment during the six weeks.
4. **Route the channel on a flag, not a timeout.** A customer session is bound to the core that owns that product. Fail closed when that core is down. Do not silently post to the core that is being decommissioned.

## 6. Limitations and Uncertainty

This model covers the US core and the hybrid estate in the migration diagram. It does not cover the Luxembourg subsidiary. That entity serves expatriate US clients and was excluded by the Rules of Engagement. Putting it in the matrix would be scope creep. Its regulatory position is also different: the US obligations (GLBA, SOX, OCC) are why the US findings matter to examiners, but the subsidiary's own obligations are not analyzed here and must not be read off this matrix.

STRIDE does not score examination risk or adversary intent. It will not tell management whether the migration should slip. It tells the architecture team which new elements are unsafe while both cores are live. The threat-intelligence briefing on US financial-sector activity was read as context for later control testing. It was not used to add actors this matrix cannot assign to an element.

## 7. Appendix: Sourced Findings

No undocumented connection inside the Rules of Engagement was available to inspect beyond the materials summarized for this engagement. Nothing in this model depends on a hidden flag. The four findings are sourced as follows.

- Finding 1 is sourced from the dual-running period described in the business context and from the two cores on the migration diagram.
- Finding 2 is sourced from the replication path that exists only in the transition state on that diagram.
- Finding 3 is sourced from the identity bridge required to operate both cores, read against the RoE's in-scope US estate.
- Finding 4 is sourced from customer channels that must select a core while both are still up.

The Luxembourg subsidiary is named here only to record that it was seen and left out.
