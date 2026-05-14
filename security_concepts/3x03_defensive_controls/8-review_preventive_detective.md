# Task 8: Review — Preventive vs. Detective Controls

## Question

What is the functional difference between a Preventive control and a Detective control? Why are both necessary, and what does the BioHealth keylogger incident demonstrate about relying on only one function?

## Answer

### Definitions

**Preventive Control:** A control whose function is to *stop an adverse event from occurring*. It operates before or during the threat event. If the preventive control works, the incident does not happen.

Examples: Firewall (blocks unauthorized connections), MFA (prevents access with stolen credentials alone), network segmentation (blocks lateral movement before it begins), USB port disable policy (prevents physical implant installation).

**Detective Control:** A control whose function is to *identify that an adverse event has occurred or is occurring*. It does not prevent the event — it generates awareness that enables response. If the detective control works but no corrective action follows, the harm continues.

Examples: SIEM/audit logs (records and alerts on anomalous events), IDS/IPS (alerts on exploit signatures), database activity monitoring (alerts on bulk queries), CCTV (records physical entry events).

### Why Both Are Necessary

No preventive control is 100% effective. Attackers bypass firewalls through authorized ports. Phishing bypasses spam filters. Hardware keyloggers bypass endpoint security. A security architecture that relies exclusively on preventive controls assumes that no control will ever fail — an assumption that every real-world breach disproves.

Detective controls are the answer to this gap: when prevention fails, detection limits the damage by enabling a timely response. The two functions form a sequential defense:

```
Threat → [Preventive Control] → Blocked (ideal outcome)
                ↓ (control bypassed)
         [Detective Control] → Alert generated → Response activated
                ↓ (no detection)
         Prolonged undetected compromise (worst outcome)
```

The time between compromise and detection is called **dwell time**. Industry data consistently shows that organizations without effective detective controls sustain average dwell times measured in months. Every day of undetected access is additional data exfiltrated, additional systems compromised, and additional evidence destroyed.

### What the BioHealth Keylogger Incident Demonstrates

The BioHealth incident is a case study in the failure of detection:

1. **Preventive controls failed:** No USB port policy, no physical access control, no MFA. The attacker installed the keylogger and captured credentials without triggering any preventive barrier.

2. **Detective controls were absent:** No SIEM, no anomaly-based authentication monitoring, no database access logging, no DLP. The attacker authenticated remotely using stolen credentials, accessed the genomic database, and exfiltrated data — and none of these events generated an alert or a log entry that was reviewed.

3. **The result:** BioHealth did not discover the incident through its own monitoring. It was discovered through an external complaint filed by a research partner. BioHealth's dwell time is unknown — it could have been weeks or months.

The incident demonstrates that preventive failure without detective capability produces the worst possible outcome: prolonged, undetected access with no opportunity for early containment. Had database access logging been active, the anomalous query volume from an unexpected IP address would have generated an alert within hours of the first unauthorized access — limiting the exfiltration window from weeks to hours.

### Operational Summary

| Function | Acts | When Prevention Fails... |
|----------|------|--------------------------|
| Preventive | Before the event | Nothing stops the attacker |
| Detective | During/after the event | Alert enables response and containment |
| Corrective | After detection | Damage is repaired and recurrence prevented |

A complete security architecture requires all three functions in sequence. Preventive controls reduce the attack surface. Detective controls identify failures in prevention. Corrective controls restore normal operations and close the exploited gap. The absence of any one function creates a structural weakness that adversaries systematically exploit.
