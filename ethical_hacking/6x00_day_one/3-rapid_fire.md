# Judgment Drill — Rapid Fire

**Author:** Junior consultant, Vanguard Security
**Standard used:** "Can I?" means the action is allowed by law and by the signed scope or Rules of Engagement. "Should I?" means the action is the right professional decision even when it is allowed. A verbal aside, a helpful motive, or a valuable finding does not move either answer.

## Cluster A — Scope boundaries

### Vignette 1 — Internal API described as a "direct dependency"

The scope allows "the web application and its direct dependencies." The application talks to an internal API that is not named in the scope, and that API appears to have an authentication bypass.

**Can you test the API?** Not yet. "Direct dependencies" might mean libraries and services the application calls, or it might mean only the components the client listed. An authentication bypass on an unnamed internal server is exactly the ambiguity that put RedLine onto FinServe's billing host. Until the client confirms in writing that this hostname is in scope, testing it is not authorized.

**Should you?** You should record the hostname, the evidence that the application calls it, and the symptom of the bypass, without exploiting it. Then you ask the engagement lead for a written scope decision. You should not exploit the bypass on the strength of a sentence that can be read two ways.

### Vignette 2 — Development host next door to the range

The signed scope is 10.0.1.0/24. A host at 10.0.2.15 answers a ping. It looks like a development server with default credentials. Someone at the kickoff said "we also have a dev environment." That sentence is not in the signed scope.

**Can you access it?** No. The signed document is the authorization. A kickoff remark does not amend it. Default credentials do not create permission. Authenticating to 10.0.2.15 would be access outside the authorized range.

**Should you?** No. You should note that 10.0.2.15 responded, from the in-scope vantage point, and send that observation to the project contact with a request to add or explicitly exclude the development network. You do not log in while you wait.

### Vignette 3 — IDOR on live customer records

The scope authorizes testing of the e-commerce application. An IDOR exposes real names, addresses, and payment data. Showing full impact would mean opening real customer records.

**Can you access the data?** Only to the extent the contract and the data-handling rules allow a proof, and only the minimum. Authorization to test the application is not authorization to bulk-collect personal data. Payment data is a further limit: PCI-DSS and the Rules of Engagement will usually forbid retaining cardholder data even when the bug is real.

**Should you?** You should prove the IDOR with one record, ideally a test account the client issued, or with a single identifier if no test account exists. You record the fields that were exposed, not the values. You do not page through the customer table to "show scale." Scale is demonstrated by showing that the identifier is predictable. You tell the client the same day, because live payment data is exposed now, not at the final readout.

## Cluster B — Incidental discoveries

### Vignette 4 — Forged invoices on an in-scope workstation

The workstation is in scope. On it you find forged invoices and wire receipts to a personal account. This looks like fraud by an employee. It is not a security vulnerability.

**Can you report this to the client?** Yes. You are already authorized to be on that workstation, and the material was found in the course of that work. Reporting it through the channel named in the Rules of Engagement is part of the engagement, not a new intrusion. You are not authorized to open a private investigation, to confront the employee, or to take the files to the police on your own.

**Should you?** Yes. You preserve the paths and timestamps, you stop digging once you have enough to describe what you saw, and you report it to the designated client contact as a confidential observation, separate from the technical findings. Hiding it would leave the client exposed. Turning it into your own fraud case would exceed both your skill and your mandate.

### Vignette 5 — A physician prescribing controlled drugs to themselves

The hospital red team includes the electronic health-record system. Inside it, a physician appears to be prescribing controlled substances to themselves under patient identifiers.

**Can you include this in your report?** You can report the fact that the conduct was observed. You cannot paste patient identifiers, clinical notes, or a prescription history into a penetration-test report. Health data is subject to its own statute (HIPAA in the United States, GDPR special-category data in Europe). The scope lets you test the system. It does not let you republish the records.

**Should you?** Yes, you should report it, and you should do it carefully. The right audience is the clinical-compliance or privacy contact named for this engagement, not the general findings meeting. The note states what was observed, which account, and when, with the minimum patient detail the hospital needs to investigate. You do not continue to browse other patients to strengthen the story.

## Cluster C — Client communication

### Vignette 6 — An outsider is already exploiting the critical bug

Halfway through a two-week test you find a critical remote-code-execution flaw that an external attacker is using now. The Rules of Engagement say findings are delivered in the final report.

**Can you break protocol and call the client now?** The clause as written says you wait. That clause did not contemplate an intruder who is already inside. An active compromise is an incident, not a draft finding. If the Rules of Engagement have an emergency path, you use it. If they do not, you still notify, and you document why you departed from the reporting schedule. Staying silent for the rest of the two weeks would make Vanguard a witness to ongoing damage.

**Should you?** Yes, immediately. You tell the designated security contact what you saw, you stop any testing that could disturb evidence, and you do not clean the attacker's access unless the client asks you to. The final report can explain the deviation. The client cannot get those days back.

### Vignette 7 — The CISO wants a board preview while the project manager is away

The CISO asks for "a preview of findings so far" for the board tomorrow. The Rules of Engagement say every communication goes through the project manager. The project manager is on vacation.

**Can you share the findings with the CISO?** No. The Rules of Engagement name the channel on purpose, so that partial results are not briefed to a board without context, and so that a single executive cannot redirect the engagement. The CISO's seniority does not amend the document.

**Should you?** No, not with the findings. You should reply that preliminary results go through the named channel, offer the backup contact if one was appointed, and ask the CISO to route the board request through that person. If nobody was appointed to cover the vacation, that gap is itself an emergency-contact failure: you escalate inside Vanguard and arrange a lawful substitute. You do not fill the gap by emailing the board pack.

## Cluster D — Engagement qualification

### Vignette 8 — "Hack us like a real attacker"

A 50-person startup, with no security team, no previous assessment, and three people in IT, asks for "the full works." They will not name a budget, a timeline, or a concern. They want to be surprised.

**Can you propose a red team engagement?** You can propose one only after the client can sign a real authorization, and a red team is not what this request describes. "Surprise us" is not a scope. A contract written in those words would repeat the InnovateTech failure: the firm would choose the tactics, and the client would discover the meaning during the incident.

**Should you?** No. A company with no baseline, no detection team, and no prior assessment does not benefit from an adversary simulation. They benefit from a vulnerability assessment or a tightly scoped penetration test, with a written list of systems and a rule that nothing is surprising. You should decline the red team, explain the difference in one page, and offer the assessment they can actually use. If they refuse to define a scope, you should decline the work.
