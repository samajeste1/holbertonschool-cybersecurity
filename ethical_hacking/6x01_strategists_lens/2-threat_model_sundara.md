# Threat Model — Sundara Lifestyle

## Framework Declaration

PASTA

## Rationale

The engagement exists to inform a board decision, stated as a whether: delay the European launch by six months, or proceed, with an IPO clock behind it. That is the word and the audience Diane Voss described. The business-context document supplies the competitor loyalty-data breach, the expansion into Germany, France, and the Netherlands, and the stakeholder split a board has to resolve. The Rules of Engagement add the jurisdictional fact the decision turns on: PDPA governs Sundara today, GDPR governs the expansion, and the loyalty data has to move between them. PASTA starts from that business objective and only then decomposes the application. STRIDE would decompose the mobile diagram and still not answer the board. ATT&CK would list retail intrusions without tying them to a launch date.

## Framework Selection Feedback

PASTA is the right strength for Sundara because stages I and II force the delay-versus-proceed decision and the PDPA/GDPR transfer to stay visible when the diagram gets interesting. Its limitation is tactical detail. A seven-stage model will under-specify a single API flaw the engineering team will eventually need. That work is a later STRIDE pass on the loyalty service, after the board has decided what is allowed to launch.

## Threat Model

Business objective (stage I). Protect the EU launch and the IPO from a loyalty-data event of the kind that already stopped a peer. The decision in front of the board is not "are we secure." It is whether the cross-border loyalty product can launch on the current date.

Technical scope (stage II). First-party: the mobile application, about 12 million loyalty accounts, integrated payment initiation, geolocation, the recommendation feature, and the cross-border reservations module. Jurisdictions in scope: Singapore PDPA for the existing processing, GDPR for any processing about people in the EU or for the EU establishments. Out of this model: POS hardware Sundara does not build or operate.

Stage III, decomposition. The loyalty profile is the asset. It is collected in Asia, stored under PDPA, and the expansion wants it available to EU stores, reservations, and marketing partners. Payment initiation and geolocation are attached to the same account. The recommendation feature processes that profile to drive offers. Reservations are the first feature that must work across the border on launch day.

Stage IV, threat analysis. The relevant threat is not a novel attacker. It is the one the threat-intelligence briefing already prices in: loyalty-data theft and retail skimming, active in Asia and in Europe, aimed at programs that are large enough to sell. A second threat is regulatory: a transfer of the Asian profile store into the EU, or a live query from an EU store back to Singapore, without a lawful transfer tool.

Stage V, weaknesses. One account store serves marketing, payment, location, and reservations, so a single access-control failure exposes the whole profile. The reservations module is the new cross-border path and is the least exercised. Marketing partnerships are a second exit for the same data. The peer breach is evidence that this class of program is being taken, not a vulnerability statement about Sundara's code.

Stage VI, attack model. An attacker who can enumerate loyalty identifiers, or who can abuse a partner feed, reads profiles at scale. Separately, and without any intrusion, launching the reservations module against the Singapore store processes EU personal data in a way PDPA did not have to answer and GDPR will. Those are different failures. Both land on the board as "the expansion was not ready."

Stage VII, impact. A loyalty-data breach in the launch window repeats the competitor precedent and damages the IPO story. A transfer that cannot be explained to a European authority delays the launch by regulator, not by choice, and does it in public. Residual risk if the board proceeds with no change: high on the cross-border profile, lower on a store opening that does not query the Asian loyalty store.

First-party versus third-party. POS hardware is not Sundara's system. Skimmer activity against retail POS, which the threat briefing correctly flags for the sector, is not modeled here as Sundara's control responsibility. It is a vendor and landlord problem. Sundara's duty is contractual: know who operates the terminals and what those contracts say. That duty is recorded in the report's limitations, not as a row in this model.

## Identified Findings

1. **The launch decision is a transfer decision.** The reservations module and any replication of the 12 million profiles into the EU are a PDPA-to-GDPR cross-border processing. If the transfer tool (an adequacy route, standard contractual clauses, or an equivalent) is not in place, proceeding on the current date is the higher-risk option. This outranks every application bug because it is true even if the application is never breached.

2. **One loyalty identifier is the blast radius.** Payment initiation, geolocation, recommendations, and reservations hang off the same account. The competitor breach was a loyalty-data event. An identifier that can be enumerated, or a partner feed that receives the full profile, is the first-party weakness that makes Sundara look like that peer.

3. **Partner feeds are an ungoverned export.** Marketing partnerships move the same profile outside Sundara. Under both PDPA and GDPR that is a disclosure, not a feature. The board cannot treat it as an integration detail.

4. **POS skimming is real and it is not this model.** The threat briefing's skimmer activity matters to the sector. It does not sit in Sundara's first-party threat model, because Sundara does not operate the terminals. Listing it here would assign Sundara a control it does not have.
