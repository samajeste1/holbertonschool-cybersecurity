# Post-Incident Analysis — Case 1: "The Handshake Deal"

**Firm:** NorthBay Consulting
**Client:** Logistics company (shipment tracking platform)
**Prepared for:** Vanguard Security, internal case review

## 1. What happened

NorthBay Consulting started a network penetration test on the strength of a phone call. The client's CTO, Mark Reeves, told the account manager that the team had his "full authorization" and should start before a board meeting. No written statement of work, no rules of engagement, and no confirmation that Reeves had authority to permit third-party access were obtained.

The team began the following Monday. Within 48 hours they found a critical SQL injection in the shipment tracking system and exploited it, extracting a sample of 500 shipping records that included customer addresses and package contents. On Wednesday the General Counsel, who had never been told a test was underway, received a SIEM alert, treated the activity as a breach, called the incident-response retainer, and notified the data protection authority.

The CEO had not approved the work. Reeves later confirmed that the authorization was verbal and that he had not informed the board, the CEO, or Legal. NorthBay received a cease-and-desist. The insurer opened an investigation, the authority opened an inquiry into unauthorized access, and the firm spent eight months in legal proceedings. The engagement was never finished.

## 2. What rule, law, or standard was violated

The access was not authorized by a person with legal authority to grant it. Under the US Computer Fraud and Abuse Act, the UK Computer Misuse Act 1990, and Article 2 of the Budapest Convention, access to a computer system is lawful only when it is authorized by the person entitled to control that access. A CTO's enthusiasm does not create that authority, and a verbal assurance is not evidence of it.

Taking 500 real customer records was also an unnecessary processing of personal data. The General Counsel's notification to the authority followed from the fact that, from the company's legal position, the access was a personal-data breach. NorthBay had no agreed lawful basis, no data-minimization limit, and no instruction from the controller.

PTES pre-engagement requires a written permission to test, a defined scope, and rules of engagement before any attack traffic is sent. CREST's code of conduct requires testers to act only within a documented authorization. NorthBay skipped all three. Exploiting the injection to bulk-extract live customer data also failed the professional duty to use the minimum data needed to prove impact.

## 3. What the correct professional behavior would have been

NorthBay should have refused to start on Monday. The account manager should have answered Reeves with a written authorization letter naming the legal entity, the systems, the dates, and the officer who has authority to bind the company, and should have required that letter to be signed by the CEO or by whoever the company's governance documents designate. Legal, the incident-response lead, and the SOC should have been on the notification list before the first packet.

On finding the SQL injection, the correct proof was a single benign query, or a query against a record the client had planted, showing that extraction was possible. Five hundred live shipping records were not required to demonstrate impact. Source IP addresses should have been given to the SOC in advance so the SIEM alert was recognized as the test.

## 4. Clauses that would have prevented this outcome

A pre-engagement pack with the following clauses would have stopped the engagement before it became a reported breach.

- **Authority to authorize.** "Testing shall not begin until a named officer, who warrants that they have legal authority to permit access to the in-scope systems, has signed this authorization. Verbal approval, including approval from a CTO, is not authorization. The signatory confirms that the CEO, General Counsel, and the security operations lead have been informed."
- **Written permission before any test traffic.** "No scanning, exploitation, or data access is permitted until the signed Rules of Engagement and this authorization are in Vanguard's possession."
- **Data minimization.** "Proof of impact shall use the smallest data set that demonstrates the issue. Testers shall not export bulk customer records. Live personal data, if encountered, is recorded by field type only and is not retained."
- **Stakeholder and SOC notification.** "The following contacts will be told the source IPs, the test window, and the emergency number before testing starts: General Counsel, SOC, incident-response retainer. An alert from those addresses during the window is the test, not a breach, unless the tester reports otherwise."
- **Stop right.** "General Counsel or the incident commander may halt all testing immediately by phone or email to the engagement lead. Testing stops until written permission to resume is received."
