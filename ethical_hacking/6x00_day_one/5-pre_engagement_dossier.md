# Pre-Engagement Dossier — Nexus Financial

**Prepared by:** Vanguard Security
**Client:** Nexus Financial
**Client contact:** James Okafor, CISO
**Engagement lead:** Sarah Chen
**Status:** Draft for lead review. Not for signature until the go/no-go list is complete.
**Proposed window:** four weeks of testing, report delivered at least two weeks before the Meridian Capital meeting

## 1. Executive Summary

Nexus Financial, a European digital-payments platform processing about €2 million a day, has asked Vanguard Security for an independent security assessment because Meridian Capital requires one before a Series B closing. This dossier defines a gray-box penetration test of the payments platform Nexus owns and operates: the core API, the customer web application, the mobile API surface, the admin panel, the AWS accounts that host them, and the remote-access edge. It is not a red team, it does not include phishing or physical intrusion, and it does not authorize any test of VerifyID's infrastructure. Testing starts only after a person with legal authority to bind Nexus Financial has signed the authorization, and after the CTO and the CFO have signed the same scope.

## 2. Scope Document

### 2.1 In-scope assets

The following are in scope once they are confirmed with hostnames, account IDs, and environments in Annex A at signature. Items marked "to be confirmed" are not in scope until the identifier is written down.

| Asset | Identifier (to be confirmed in Annex A) | Environment |
| --- | --- | --- |
| Core payments API | Rails application on Amazon EKS, eu-west-1 | Staging first, then production under the limits in the Rules of Engagement |
| Customer web application | Public web front end that calls the core API | Staging, then production under the same limits |
| Mobile application API | The same core API as used by the iOS and Android clients | API only. No binary reversing unless added by change request |
| Admin panel | admin.nexus-financial.com | Staging and production, test accounts only |
| AWS accounts that host the above | Named account IDs in eu-west-1: EKS, RDS (PostgreSQL), S3, and the IAM roles that serve them | Read-only assessment plus non-disruptive checks |
| Remote-access edge | WireGuard VPN used by staff | Authentication and exposure only, from Vanguard source addresses |
| Nexus-side VerifyID integration | The Nexus endpoint and the code path that calls VerifyID | Nexus infrastructure only |

Test accounts, a read-only AWS role, and architecture diagrams are required inputs. They do not expand the list above.

### 2.2 Out-of-scope assets

| Asset | Why it is excluded |
| --- | --- |
| VerifyID's API, tenancy, and infrastructure | Nexus does not own or operate it. James Okafor confirmed this on the scoping call. ClientCorp's billing incident is the precedent: a client's contract with a vendor is not authorization to enter the vendor. |
| Stripe, the payment gateway | Third-party platform. Nexus can authorize tests of its own calls to Stripe, not of Stripe. |
| Corporate laptops, email, and the internal office network beyond the VPN edge | Not required to answer the investor question, and not staffed as a red team. |
| Social engineering, phishing, vishing, and physical entry | The CEO-style request from the CTO is not informed consent. No employee list, no pretext, and no premises are authorized. |
| Denial of service, volumetric testing, and ransomware simulation | Direct conflict with the CFO's availability constraint during due diligence. |
| Other AWS accounts, regions, and personal accounts of staff | "We use AWS" is not an account ID. |
| Production payment execution that moves real funds | A successful test must not create a transaction. |

### 2.3 Scope boundaries

**VerifyID.** Vanguard will test how Nexus authenticates to VerifyID, what data Nexus sends, and how Nexus handles the answer, using synthetic identities on the Nexus side. Vanguard will not send real customer dossiers, will not attack VerifyID, and will not submit test traffic to VerifyID's API unless VerifyID has signed its own authorization. If that signature is not available, the integration is tested only up to the point where the request would leave Nexus.

**Staging and production.** Discovery, authentication tests, and exploit development happen on staging, which James described as a mirror of production. A finding is then validated on production only if staging cannot prove it, only inside the authorized hours, only with a test account, and only after the CFO's delegate has accepted that specific check. Production is not the place where Vanguard explores.

**Social engineering.** Thomas asked for a phishing campaign against all employees. This engagement declines it. Nexus has no prior assessment, a CISO of three months, and a funding deadline. A phishing exercise needs a separate statement of what is allowed, a employee-communication plan, and a decision from the CFO as well as the CTO. It can be a later addendum. It is not implied by "hack us like a real attacker."

**Mobile applications.** The API the apps call is in scope. Reverse engineering of the iOS and Android binaries is out of scope for this four-week window. If a finding requires the binary, it is written up as a change request.

**"Everything."** The CTO's request to test everything is recorded and refused as a scope. Everything is not a list of assets, and it is how the InnovateTech engagement became a police call.

## 3. Rules of Engagement

### 3.1 Testing windows

Active testing, including any production validation, runs from 09:00 to 18:00 CET on business days. Thomas's point that real attackers do not keep office hours is understood and is the reason a later red team might use different hours. It is not a reason to put payment processing at risk in the six weeks before an investor meeting. Passive review of materials the client has already handed over may happen outside that window. No testing on the two days immediately before the investor meeting.

### 3.2 Testing approach

The approach is gray box. A black-box test would spend the first week rediscovering architecture the CISO can hand over, and it would increase the chance of hitting production blind. A white-box source audit of the entire platform does not fit four weeks and is not what the investor asked for. Gray box means: architecture diagrams, test accounts for the API and the admin panel, a read-only view of the Rails routes or equivalent, and a read-only AWS role. Exploitation is a proof, not a campaign. One test record is enough. Bulk export of customers, bank details, or KYC dossiers is forbidden.

### 3.3 Communication protocols

Day-to-day traffic goes from the Vanguard engagement lead to James Okafor, and from James to Vanguard, on the channel in the communication plan. Testers do not take direction from the CTO or the CFO directly. A request to add phishing, to "try production properly," or to look at VerifyID is a scope change, and it comes back through Sarah Chen before anyone acts on it.

### 3.4 Emergency stop

Any of the following stops testing immediately: a payment-processing error that might be related to the test, a client instruction to stop, discovery of an active intruder, or loss of contact with the client emergency number for more than 30 minutes during a production check. The Vanguard lead calls the stop, confirms it to James and to the CFO's delegate by phone, and the testers drop their sessions. Testing resumes only on a written note from James and from Sarah. A stop is not a failure of the engagement.

### 3.5 Data handling

Nexus processes names, addresses, and bank details and is subject to GDPR. Vanguard's instruction is to avoid that data. Test accounts and synthetic identities are the dataset. If a response contains real personal data, the tester records the endpoint and the field names, not the values, closes the record, and tells the engagement lead the same day. Copies, if any were made in a log by accident, are deleted within 72 hours and in any case at the end of the engagement. Working files stay in the EU, encrypted, and accessible to the engagement team only. Vanguard does not use live customer data in the report, in screenshots, or in a proof-of-concept repository. Retention of notes is 90 days after the final report unless Nexus instructs a shorter period. A processing record for this engagement is attached to the contract.

### 3.6 Incident discovery

If the testers find evidence that someone else is already in the environment, they stop the affected activity, preserve the logs they have, and call James Okafor and the emergency contact within one hour. They do not remediate, do not delete the intruder's access, and do not wait for the final report. The final-report schedule does not apply to an intrusion in progress.

## 4. Communication Plan

### 4.1 Points of contact

| Role | Name | Responsibility |
| --- | --- | --- |
| Client sponsor | James Okafor, CISO | Day-to-day decisions inside the signed scope |
| Client availability | Maria, CFO, or a named delegate | Accepts or refuses each production validation |
| Client technical authority | Thomas, CTO | Consulted on scope changes. Cannot add tactics by himself |
| Authorizing officer | To be named. Not James alone | Signs the authorization. Must have authority to bind Nexus Financial |
| Vanguard lead | Sarah Chen | Only Vanguard voice to the client |
| Vanguard backup | To be named before kickoff | Covers leave. The Case 7 failure was a project manager on vacation with no deputy |

The board point that James made, that the CTO and the CFO can approve if they agree, is accepted only as a signature block. Both sign, or the officer who actually holds authority signs. A CISO of three months does not self-certify that authority. That is the Handshake Deal.

### 4.2 Reporting cadence

- Kickoff, the day testing is allowed to start.
- A short written status at the end of each week: what was tested, what was not, any stop or scope question. No surprise findings saved for the end.
- Same-day notice for a critical issue on production, for any personal-data exposure, and for any sign of an existing intruder.
- Draft report one week before the investor pack is due, so James can check facts.
- Final report and a readout at least two weeks before the Meridian meeting, as James requested.

### 4.3 Stakeholder management

The CTO and the CFO are both right about a different engagement. Thomas wants adversary realism, including phishing and unrestricted hours. Maria wants no disruption during due diligence. This dossier does not split the difference by doing a quiet red team. It gives Maria a bounded test with office hours and a production gate, and it gives Thomas a written record of what was deferred and why. James is the sponsor inside that boundary. If the three of them do not sign the same scope, Vanguard does not start. A test that one board member can later disown is not a test Vanguard will run.

### 4.4 Secure channels

Status mail is not sent to personal webmail. The working channel is a Vanguard project address plus a Nexus address on the company domain, with S/MIME or an agreed encrypted share for anything that contains a finding. Phone numbers for the stop procedure are exchanged at kickoff and tested once. Findings do not go into the investor data room until the final report is issued.

## 5. Risk Register

These are risks to the engagement, not vulnerabilities in Nexus.

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| 1 | The CISO signs and later lacks authority. The CEO or the insurer treats the test as unauthorized access. | Medium | Severe. Cease-and-desist, a regulatory notification, an unfinished report. | No start until the authorizing officer named in section 4 has signed. Legal and the SOC receive the source IPs before the first scan. |
| 2 | A production check interrupts payment processing during due diligence. | Medium | Severe. Direct revenue loss and damage to the round. | Staging first. Production checks are individual, inside 09:00–18:00 CET, and accepted by the CFO's delegate. No load testing and no real-fund transactions. |
| 3 | A tester follows the VerifyID or Stripe integration into the vendor's system. | Medium | Severe. Unauthorized access to a third party, as in the billing-platform case. | Both vendors are out of scope in section 2. Traffic that would leave Nexus is not sent unless that vendor has signed. |
| 4 | The CTO expands the job in conversation: phishing, night testing, "everything." | High | High. The firm executes tactics the CFO did not accept. | Testers take instructions only from the Vanguard lead. Scope changes are written. Social engineering stays out. |
| 5 | A proof captures real customer or cardholder data and retains it. | Medium | High. GDPR exposure and a report that should not exist. | Test accounts only. Field names, not values. Accidental copies deleted within 72 hours. Screenshots reviewed before they enter the report. |
| 6 | The team finds an active intruder and follows the ordinary weekly status cycle. | Low | Severe. The attacker keeps the access. | Section 3.6 requires a call within one hour. The final-report rule does not apply. |
| 7 | Four weeks is too short, and the investor date slips. | Medium | High. Meridian does not get the assessment it asked for. | Scope is the platform Nexus owns, not a red team. Weekly status surfaces slippage in week one, not week four. |

## 6. Go / No-Go Checklist

Testing does not start while any line is open. A verbal yes on the scoping call is not a closed line.

- [ ] The legal name of the client entity is written on the authorization.
- [ ] A person who warrants they have authority to permit access to the in-scope systems has signed. James Okafor's signature alone does not close this line.
- [ ] The CTO and the CFO have signed the same scope, including the exclusion of phishing, physical entry, VerifyID, and Stripe.
- [ ] Annex A lists hostnames, AWS account IDs, and which checks may touch production.
- [ ] VerifyID has either signed a separate authorization or been confirmed in writing as "do not send traffic."
- [ ] Staging is reachable, and test accounts exist for the API and the admin panel.
- [ ] A read-only AWS role, if cloud checks are included, is limited to the named accounts.
- [ ] Source IP addresses and the test window have been sent to whoever watches the SIEM, so the test is not reported as a breach.
- [ ] Emergency numbers are filled, including a Vanguard backup and a client backup, and the stop call has been placed once.
- [ ] The data-handling rules in section 3.5 are attached to the contract.
- [ ] The CFO's delegate for production checks is named.
- [ ] The report date is still at least two weeks before the investor meeting. If it is not, the scope is cut in writing before testing starts, not during it.

If a line cannot be closed, the engagement does not begin. That is the decision this dossier is for.
