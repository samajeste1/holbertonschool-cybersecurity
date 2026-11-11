# Vanguard Security: Threat Modeling Engagement Report
## Client: Sundara Lifestyle

**Prepared by:** samajeste1, Junior Consultant
**Date:** 12 November 2026
**Distribution:** Sundara board (CFO, CEO, independent directors)

## 1. Executive Summary

The board is deciding whether to delay the European launch by six months or to proceed, with the IPO behind that choice. The binding risk is not a list of application bugs. It is that the loyalty program, about 12 million accounts, was built under Singapore's PDPA and the expansion would process those profiles for people and stores in the EU, where GDPR applies. A peer retailer has already lost an EU launch to a loyalty-data breach. Proceeding on the current date is acceptable only for openings that do not query or copy the Asian profile store. The cross-border reservations module, and any bulk move of profiles, should wait until a lawful transfer mechanism is in place and the loyalty identifier cannot be read in bulk. Payment terminals are not part of this decision. Sundara does not operate them.

## 2. Engagement Context

Sundara is a Singapore-based premium outdoor and wellness retailer, 180 stores across Singapore, Malaysia, Indonesia, Thailand, and Hong Kong, opening in Germany, France, and the Netherlands. Vanguard was engaged after a comparable Asian brand lost its EU launch to a loyalty-data breach. The materials that matter are the business-context document (the whether, the IPO, the peer breach) and the Rules of Engagement (PDPA now, GDPR for the expansion, POS hardware outside Sundara's operation).

## 3. Framework Choice and Rationale

PASTA. The business-context document frames a board decision under a deadline, which is a strategic question, and the Rules of Engagement make the answer depend on two privacy regimes and a third-party boundary. PASTA keeps that objective in front of the application diagram. A component-by-component security decomposition would give the board a matrix it cannot use in two minutes. An adversary-technique catalogue would describe retail intrusions without saying whether to launch.

## 4. Threat Model

The objective is to avoid becoming the next loyalty-data story in the month the EU stores open. The in-scope application is the mobile loyalty program: profiles, payment initiation, geolocation, recommendations, and cross-border reservations. PDPA covers the processing Sundara does today from Singapore. GDPR covers processing about people in the EU and processing by the new EU establishments. A transfer between those regimes is a first-class threat even when nobody breaks in.

The attack that matches the threat briefing is bulk theft of loyalty profiles, through an enumerable identifier or through a partner feed. The weakness is structural: one account is the profile, the payment handle, the location history, and the reservation. Impact is a launch-window breach, or a public finding that the transfer had no lawful basis. Either one damages the IPO story the peer breach already illustrated.

POS hardware is not in this model. Sundara does not build or run it. Sector skimming is noted in the limitations so it is not mistaken for a forgotten row.

## 5. Recommendations and Prioritization

1. **Do not launch the cross-border profile.** Reservations and any copy of the Asian loyalty store into the EU wait until counsel has a documented transfer tool and a stated purpose for each field that moves. Store openings that use a separate, EU-collected program can proceed. That is the delay-versus-proceed split, and it is narrower than a six-month freeze of the whole expansion.
2. **Stop full-profile partner feeds.** Marketing partners receive an offer token, not the profile. This is a disclosure under both PDPA and GDPR, and it is the export an attacker does not have to steal.
3. **Remove bulk reads of the loyalty identifier.** One test account must not imply the next million. This is the control that makes Sundara a worse target than the peer who was breached.
4. **Keep payment and location off the same response** as the marketing profile. The application can still function. The stolen record becomes less useful.

## 6. Limitations and Uncertainty

This model does not assess POS hardware, POS vendors, or landlord networks. The threat-intelligence briefing is right that skimming is active in Asian and European retail. Those terminals are third-party managed. Treating them as Sundara's first-party system would invent a responsibility Sundara does not have. Sundara's actual lever is the contract with the terminal operator, which is a procurement question, not a row in this threat model.

PDPA and GDPR are not the same duty with two names. PDPA governs the Singapore controller. GDPR governs the EU expansion and people in the EU. Their interaction shows up at the moment a Singapore store of profiles is queried or copied for Europe. This paper does not give a legal opinion on which transfer tool fits. It says the launch is not ready while that choice is still open. Adequacy, clauses, and local filings move, and counsel has to own the final instrument.

PASTA will not hand the engineering team a ticket-level decomposition of the loyalty API. That is a later pass, after the board decides what is allowed to go live.

## 7. Appendix: Sourced Findings

No unmapped cross-border relationship beyond the reservations module and the profile store was available to trace outside the materials in this brief. No flag is claimed.

- Finding 1 is sourced from the business-context expansion plan and from the RoE's PDPA and GDPR clauses, read together.
- Finding 2 is sourced from the mobile architecture: one loyalty account bound to payment, geolocation, recommendations, and reservations, set next to the peer breach in the business context.
- Finding 3 is sourced from the marketing partnerships named in the business context.
- The POS exclusion is sourced from the business documents' statement that Sundara does not build or operate POS hardware, and from the threat briefing's retail-skimmer items, which are deliberately not given a first-party row.
