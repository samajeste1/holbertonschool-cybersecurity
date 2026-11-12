# Rules of Engagement, Lumen Industrial Systems

## Engagement Metadata

- **Client:** Lumen Industrial Systems, Brno, Czech Republic.
- **Engagement reference:** VGD-LUM-2026-042.
- **Engagement type:** External and authenticated penetration test under the Penetration Testing Execution Standard. The report is written so it can sit in a NIS2 conformity packet. It is not a red team and it is not a certification.
- **Engagement window:** 16 November 2026 through 27 November 2026. Active testing only inside the window in the next section. Reporting closes five business days after the last test day.
- **Signing parties:** For Lumen, the CISO, who warrants that Lumen has legal authority over every asset listed as in scope. For Vanguard Security, Sarah Chen, engagement lead, and samajeste1, junior consultant. A signature by a sales contact, or a verbal go-ahead tied to the Series A date, is not authorization.

## Scope

### In Scope

Lumen-controlled systems only:

- The cloud-hosted monitoring platform Lumen operates for its own service.
- The public REST API on that platform.
- The internal admin panel used by Lumen staff.
- The demo edge gateway Lumen runs in-house for QA and sales demonstrations, including SSH on that gateway only.
- The demo MQTT broker Lumen runs in-house for the same QA and sales use.

Public reconnaissance is limited to Lumen's own domains, the public API surface, and information Lumen has already published (marketing pages, public DNS, cached pages, staff who identify themselves as Lumen employees).

### Out of Scope

- Edge gateways installed at an industrial customer's premises.
- IoT sensors on a customer's shop floor.
- Any network, VPN, or management plane that belongs to a Lumen customer, including German and Austrian mid-cap sites named in marketing.
- Denial-of-service, ransomware simulation, and any test whose purpose is to stop a production line.
- Social engineering of Lumen staff or of customer staff.

**Legal reasoning.** Lumen sells monitoring. It does not own the gateways and sensors once they are deployed at a customer site, and it cannot consent to intrusion on a customer's system. NIS2 makes those customers essential entities. Their own obligations do not transfer a right to test their plants. A host that answers from the demo environment, or that is named on a public case study, is still out of scope if it is customer property. Reachability is not authorization. Probing one of those assets would be the act that ends this contract.

## Testing Window

- **Days:** Monday to Friday, 16–20 November and 23–27 November 2026.
- **Hours:** 09:00–17:00 Europe/Prague.
- **Blackouts:** Weekends. 17 November 2026 (Czech Struggle for Freedom and Democracy Day). Any hour a customer production line would be in a change window if the target cannot be shown to be the in-house demo. No testing after 17:00 even if a foothold is mid-step. The session is closed and resumed the next allowed day.

The renewals are eight weeks out. That commercial date does not extend the window and does not justify night testing.

## Communication and Escalation

- **Primary contact:** Lumen CISO. Response expected within two hours during the testing window.
- **Secondary contact:** Lumen deputy named in writing before the first scan. If no deputy is named, testing does not start. A single contact on leave is not an escalation path.
- **Vanguard lead:** Sarah Chen. Consultants do not take scope changes from anyone else.
- **Channel:** Company email on both sides, plus a phone number tested once at kickoff for stop calls. Findings do not go to personal mail or to a customer of Lumen.
- **Escalation:** Consultant to Sarah Chen to the Lumen CISO. A suspected active incident is a phone call, not the daily status mail.
- **Response times:** Routine questions, four business hours. Stop or incident, immediate, and testing halts while the call is outstanding.

## Authorised Tools, Forbidden Tools

**Authorised:** Nmap and similar scanners limited to in-scope hosts. Browser and Burp Suite against the portal, admin panel, and API. curl and manual HTTP. SSH to the demo gateway only. An MQTT client against the in-house demo broker only. Hand-written payloads and documented public techniques for the file-upload check. Scripts the consultant can explain line by line in the action log.

**Forbidden:** Metasploit for the initial foothold. A module that delivers the first code execution is not allowed. Metasploit may be used later only for a post-exploitation utility, and only if the log states why a manual command was not enough. Exploit packs aimed at customer PLCs, scanners pointed at customer sites, password spraying of customer staff, and any destructive payload.

## Stop Conditions

Testing stops immediately, and the CISO is called, if any of the following is true:

- The next host is a customer gateway, a shop-floor sensor, or anything the RoE lists as out of scope, even if it is one hop from the demo broker.
- A command would change or stop a process that is not the in-house demo.
- The team finds evidence that someone else is already in the system.
- Lumen, or a customer, reports impact.
- The consultant cannot explain a tool or a payload in the action log.
- Authorization is disputed.

Work resumes only when Sarah Chen and the Lumen CISO both confirm it in writing.

## Data Handling

The expected data is demo and QA data. If a response contains a real customer name, a site address, production telemetry, or credentials that reach a customer broker, the consultant records the field type and the endpoint, not the values, and stops that thread. Copies in tool logs are deleted within 72 hours. Working files stay encrypted, in the EU, and available only to the named engagement team. Nothing from this test is reused as a sample in another engagement.

## Post-Engagement Obligations

- Draft report five business days after the last test day. Final report after Lumen's factual review.
- Evidence retained 90 days, then destroyed, unless Lumen's counsel instructs a shorter period in writing.
- Audit-support window of 30 days for questions from the three industrial customers' auditors about what was in scope and what was not. Vanguard does not brief those customers directly unless Lumen asks in writing.
- Every artefact placed on a Lumen system is removed before the report is issued, and the removal is a log line with a check that the artefact is gone.

## Signatures

| Party | Name and role | Signature | Date |
| --- | --- | --- | --- |
| Lumen Industrial Systems | CISO, warranting authority over the in-scope assets only | | |
| Vanguard Security | Sarah Chen, engagement lead | | |
| Vanguard Security | samajeste1, junior consultant | | |

Testing does not start on an unsigned copy.
