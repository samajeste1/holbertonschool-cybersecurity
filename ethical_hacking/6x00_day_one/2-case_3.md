# Post-Incident Analysis — Case 3: "The Overreach"

**Firm:** Apex Security Partners
**Client:** InnovateTech
**Prepared for:** Vanguard Security, internal case review

## 1. What happened

InnovateTech's CEO asked Apex Security Partners for a "red team assessment" after reading about red teaming in a business magazine. During the sale, the account manager did not establish what the CEO actually wanted. The CEO kept using the phrase, and the contract copied it.

Apex applied the professional meaning of red team: an adversary simulation that can include network exploitation, social engineering, and physical intrusion. Three weeks in, a consultant dressed as a delivery courier tailgated into InnovateTech's headquarters and entered a server room. A camera recorded it. A facilities manager challenged him and called building security. The police were called.

The CEO's reaction was that he had wanted the website tested and, possibly, some phishing. He had not agreed to anyone entering the building. The contract said "red team assessment" and nothing else. It had no physical-testing addendum, no list of authorized sites, and no authorization letter that could be shown to law enforcement. Apex argued that "red team" includes physical testing by definition. InnovateTech argued that permission to enter a building is not implied. The engagement was terminated. The police did not charge the consultant, but the story reached the local news. InnovateTech published a review calling Apex reckless. Two pending clients withdrew.

## 2. What rule, law, or standard was violated

Physical entry without express permission is not covered by a vague cyber testing contract. Trespass and burglary statutes are territorial and are enforced by local police who were not told that a test was underway. The absence of a "get out of jail" letter mattered because that letter is what tells an officer that the entry was authorized by the occupier. Without it, the consultant had no evidence of consent at the moment it was needed.

The contract also failed PTES pre-engagement. PTES requires the engagement type, the tactics that are allowed, and the tactics that are forbidden to be written in language the client can understand. CREST's code of conduct requires consultants not to rely on jargon the client does not share. Apex sold a label and then executed a methodology the buyer had not accepted. That is a failure of informed consent, not a disagreement about vocabulary.

## 3. What the correct professional behavior would have been

The account manager should have translated "red team" in the first meeting. The question to the CEO was: do you want a penetration test of named systems, a phishing exercise, a physical intrusion test, or all three? Each answer has its own authorization, its own risk, and its own price.

If the client wanted only the website and phishing, the contract should have said so and should have stated that physical entry was excluded. If the client truly wanted physical testing, Apex should have stopped until there was a physical addendum: sites, dates, hours, the legend the tester may use, a prohibition on forcing locks or touching safety systems, a named host on site, and a letter addressed to law enforcement. Local security and, where appropriate, the police should have been notified through the client's counsel before the attempt. None of that is implied by the two words "red team."

## 4. Clauses that would have prevented this outcome

- **Plain-language engagement type.** "This engagement is a penetration test of the systems in Annex A and a phishing exercise against the mailbox list in Annex B. It is not a red-team exercise. Physical entry, tailgating, badge cloning, and any presence on client or landlord premises are out of scope."
- **No implied tactics.** "Industry terms in a sales conversation do not add tactics. A tactic is in scope only if this document names it."
- **Physical-testing addendum, if ever used.** "Physical testing requires a separate addendum signed by the person who controls the premises. The addendum lists buildings, floors, dates, permitted pretexts, and prohibited acts. It includes an authorization letter that the tester carries and may present to building security or the police. The tester does not proceed if that letter is not in hand."
- **Law-enforcement notification.** "Before any physical attempt, the client's counsel confirms whether local law enforcement must be notified and records that notification."
- **Termination for ambiguity.** "If the client and the firm do not share a written definition of the work, testing does not start."
