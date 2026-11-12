# Penetration Test Report, Lumen Industrial Systems

**Engagement reference:** VGD-LUM-2026-042
**Reporting period:** 16–27 November 2026
**Prepared by:** samajeste1, Junior Consultant, Vanguard Security
**Distribution:** Lumen CISO, for onward use in the NIS2 conformity packet. Not for direct release to a customer plant.

## 1. Executive Summary

Lumen's in-house admin panel accepted an uploaded file that the server later executed, and a demo credential visible in a public API response reached Lumen's own demo management view. That is a confirmed access-control failure on systems Lumen operates. It is the kind of failure Article 21 of Directive (EU) 2022/2555 expects a supplier to manage, and it is material to the three renewals because those customers must be able to rely on the supplier's platform. It is not a test of their factories. Gateways and sensors on customer premises were out of scope, were seen in public material, and were not touched. The test did not observe an intruder already in the environment, so this report is not an Article 23 incident notification. The artefacts placed during the test were removed and the removal was checked.

## 2. Scope and Methodology

The signed Rules of Engagement, VGD-LUM-2026-042, are the scope. In scope: the cloud platform, the public API, the internal admin panel, the in-house demo edge gateway, and the in-house demo MQTT broker. Out of scope: customer edge gateways, shop-floor sensors, and any network Lumen does not have the legal authority to open. Publication of a customer name, or a route from the demo broker toward a customer hostname, was not treated as permission.

The method is the seven PTES phases, in order. Active testing ran on weekdays, 09:00–17:00 Europe/Prague, with 17 November 2026 held as a blackout. The first code execution was a hand-written polyglot upload. Metasploit was not used for that foothold and was not needed afterwards. Every significant step in Phases 4, 5, and 6 is a row in the action log. Where this report says something was confirmed, the log has a result. Where it says identified, the log does not claim a successful exploit.

## 3. PTES Phase Summary

**Pre-engagement.** The RoE was written and is the contract for everything below. The gap in the original brief, window, deputy contact, tools, and stop rules, was filled there and not left to the week of the test.

**Intelligence gathering.** Public pages, public DNS, and the public API were reviewed. Customer brand names and one plant hostname appeared. They were logged as seen and were not enumerated.

**Threat modeling.** Twelve threats, tagged with PASTA where the renewal and NIS2 decision is the point, STRIDE on the platform and the panel, and a MITRE technique only where an in-scope demo surface already matched one. No row targets a customer asset.

**Vulnerability analysis.** The five in-scope surfaces were identified. The upload control, the extra field in an API response, and the demo gateway's SSH banner are identifications. They were not all confirmed.

**Exploitation.** The upload was confirmed: the stored polyglot ran as the application user. The API token was then used only against a Lumen admin route and the in-house demo management view. No customer broker was opened.

**Post-exploitation.** The data classes actually reached were demo site records, demo connection material, and the application user's identity. Article 21 is the relevant obligation. Article 23 was considered and not triggered by the test.

**Reporting.** This document. Severity is tied to Lumen's renewals and to the supplier measures in Article 21, not to a generic score copied from a scanner.

## 4. Findings

### 4.1 Admin upload executes stored content, Severity Critical

- **Technical description.** The internal admin panel validates an upload as an image and then serves the stored object through a component that executes server-side content. A single polyglot file, image header plus executable content, was accepted and ran as the application user. This is confirmed. The confirmation command was `id`. No framework delivered the payload.
- **CVSS environmental.** CVSS:3.1/AV:A/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:H, environmental 9.0. Attack vector is adjacent rather than internet-wide because the panel is the internal admin, and the test used an issued account, so privileges required are low. Scope is changed because execution reaches the platform behind the panel, which is a different authority from the upload form. Confidentiality, integrity, and availability of that platform are high in this environment: the platform is the service the renewals depend on. A generic base score that assumes a public anonymous upload would be the wrong number, and a score that ignores the platform behind the form would be the wrong number in the other direction.
- **NIS2.** Article 21(2)(d) and (e), access control and security of the information system that provides the service. Article 21(2)(j), the supplier's own practices, which is the point of putting this report in a customer packet. Article 23 does not apply to the test.
- **Business impact.** An auditor at a NIS2 customer can treat code execution on the supplier's admin plane as a failure of the control Lumen is asking them to renew against. The Series A condition does not make the finding smaller.
- **Remediation.** Store uploads outside the web root. Serve them from a type that cannot be executed. Check content, not only the extension and the declared type. Remove the proof object, which was done on 20 November 2026 and verified by listing.

### 4.2 Demo credential in a public API response, Severity High

- **Technical description.** A demo call to the public API returned a connection string and a token. That token then opened a Lumen admin route. Identification was the response field. Confirmation was the later call, limited to Lumen's demo management list.
- **CVSS environmental.** CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:L/A:N, environmental 7.1. The API is on the internet, so the vector is network. The token was in an authenticated demo response, so this is not scored as anonymous. Integrity impact stays low because the confirmed use was read access to demo registration, not a write to a customer line.
- **NIS2.** Article 21(2)(d) and (i): access control, and the handling of data the platform exposes. The field is a secret in a client-facing API.
- **Business impact.** A customer integrator, or anyone with the demo account, receives material that was meant to stay in QA. If that material is ever a production broker credential, the finding jumps to the renewals immediately. In this test it reached the demo list only.
- **Remediation.** Demo responses return identifiers, not secrets. Tokens for QA are bound to the demo broker and expire. The token used here was revoked and a repeat call failed.

### 4.3 Production ingest trusts the demo path, Severity High

- **Technical description.** The management view reached after the pivot registers the in-house demo gateway on the same plane used to describe sites. This was confirmed as visibility of demo registration. It was not confirmed as a write into a live customer topic. The threat is that the platform does not keep QA and customer ingest apart.
- **CVSS environmental.** Not scored as a confirmed write. Treated as High on qualitative grounds: if the separation is only conventional, the impact on integrity of customer telemetry would be high. Inflating this to a confirmed exploit would mislead the auditor.
- **NIS2.** Article 21(2)(e) and (d). Separation of environments is part of running the service safely.
- **Business impact.** The conformity packet cannot say that customer lines are isolated from sales demos unless the platform enforces that split.
- **Remediation.** Separate credentials, topics, and roles for the demo broker and the production ingest. A demo token must fail against any non-demo endpoint.

### 4.4 Demo gateway SSH and demo MQTT, Severity Medium

- **Technical description.** The in-house gateway presents SSH. The in-house MQTT listener is up. Neither was confirmed with a guessed password, and neither was used as a route to a customer site. These are identifications.
- **CVSS.** Not scored as confirmed compromise. Medium, because both hosts are Lumen's and both are on the management path a confirmed admin flaw could reach.
- **NIS2.** Article 21(2)(a) and (d): policies and access control for the systems that support the service, including QA systems that share a control plane.
- **Business impact.** A QA SSH key reused at a customer would be a different and worse finding. This test did not look for that reuse on customer networks, and it must not be written as if it had.
- **Remediation.** Unique credentials for the demo gateway. Authentication required on the demo broker. No shared secret with a deployed gateway.

## 5. Exploitation Narrative

Each step is a row in the action log.

The foothold is the 09:41 UTC upload on 18 November. The panel stored the polyglot and executed it as the application user. The log line is `id`. Metasploit was not used.

The pivot is the 10:15 UTC call the same day. The token identified on 16 November in the public API was sent only to a Lumen admin route. The result was a list of demo sites.

The impact is the 10:36 UTC read of the in-house IoT demo management view: demo gateway registration and demo topic names. The next log line records that any other gateway on that list was not opened.

Phase 6, 20 November, records the data classes, the Article 21 / Article 23 distinction, deletion of the upload, the empty check for accounts and scheduled tasks, and revocation of the demo token.

## 6. Recommendations

**Short term, before the conformity packet is sent.** Remove executable upload handling. Confirm the proof file is gone, which the log already checks. Revoke demo tokens that have appeared in API responses. State in the packet, in one sentence, that customer premises were not in the test.

**Next, still before the renewals.** Split demo and production credentials and topics. Take the SSH and MQTT findings from "identified" to "fixed or formally accepted" on the in-house hosts only.

**Longer term.** Give the admin plane per-user audit records. Keep QA systems on a role that cannot register a production site. When a customer renewal asks about plant sensors, the answer is a separate authorization from that customer, not an extension of this report.

## 7. Limitations and Uncertainty

Customer gateways and shop-floor sensors were not tested. One plant hostname was visible on a public case study. It was not resolved. A reader who wants a statement about those plants will not find it here, and should not infer one.

SSH on the demo gateway and authentication on the demo broker were identified and not confirmed by login. The report does not call them exploited.

The polyglot proves code execution as the application user. It does not prove root, and it does not prove a path onto a production line. The management view proves that demo registration is readable from the pivoted admin route. It does not prove a write to customer telemetry.

No active third-party intrusion was observed. Article 23 is cited so the CISO can see it was considered. It is not a notice.

Commercial pressure to soften finding 4.1 for the Series A was not applied by rewriting the severity. The renewals depend on an accurate packet. A softer sentence would be a misrepresentation to the customers' auditors.

## 8. Appendices

### A. Sourced findings

- 4.1 from the Phase 5 upload rows of 18 November 2026, 09:10 through 09:44 UTC.
- 4.2 from the Phase 4 API row of 16 November, 09:05 UTC, and the Phase 5 pivot row of 18 November, 10:15 UTC.
- 4.3 from the Phase 5 management-view row of 18 November, 10:36 UTC, kept as visibility rather than a confirmed write.
- 4.4 from the Phase 4 gateway and broker rows of 16 November, 10:02 and 10:18 UTC.
- The scope omission is the Phase 4 row of 16 November, 10:33 UTC.

### B. Action log excerpt

The full log is `3-actions_log.md`. The rows an auditor needs first are: RoE check (16 November 08:05), customer hostname not scanned (16 November 10:33), polyglot upload and `id` (18 November 09:41 and 09:44), API token pivot (18 November 10:15), demo management read (18 November 10:36), file removal and token revocation (20 November 09:40 and 10:05).

### C. Framework references

- Penetration Testing Execution Standard, seven phases, in the order used in section 3.
- Directive (EU) 2022/2555, Article 21 (risk-management measures) and Article 23 (incident reporting), used only as cited in the findings.
- ENISA good practices on supply-chain cybersecurity, for the limit that a supplier test does not authorize testing of the customer.
- OWASP file-upload guidance, used as the prevention model for finding 4.1. The payload itself is not reproduced in this report.
