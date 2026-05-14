# Task 1: The Function Matrix

## Control Function Classification

Security controls are classified not only by *category* (Administrative, Technical, Physical) but by *function* — what the control is designed to do. The five functions are: **Preventive**, **Detective**, **Corrective**, **Deterrent**, and **Compensating**.

| Control Example | Category | Function | Justification |
|----------------|----------|----------|---------------|
| Firewall / AWS Security Groups | Technical | Preventive | Blocks unauthorized connections before they reach internal systems |
| Antivirus / EDR | Technical | Detective + Corrective | Detects malicious code; quarantines or removes it after detection |
| Security Awareness Training | Administrative | Preventive | Reduces the probability of human-initiated incidents (phishing, misuse) by modifying behavior through education — enforcement is policy-based, not automated |
| Acceptable Use Policy (AUP) | Administrative | Deterrent + Preventive | Deters misuse by establishing explicit consequences; prevents violations through documented prohibitions |
| CCTV / Security Cameras | Physical | Detective | Records events for post-incident review; does not block the threat |
| Padlock on Server Room | Physical | Preventive + Deterrent | Physically prevents unauthorized entry; visible presence deters attempts |
| Incident Response Plan | Administrative | Corrective | Defines the organized response to restore normal operations after an incident |
| Network Segmentation | Technical | Preventive | Prevents lateral movement by isolating network zones |
| Compensating Control (e.g., network isolation for Windows XP MRI) | Technical | Compensating | Reduces residual risk of an unmitigable vulnerability to an acceptable level when primary remediation is not feasible |
| Audit Logs / SIEM | Technical | Detective | Records events to enable detection of anomalies and post-incident forensics |

### Critical Distinction: Security Awareness Training as Administrative Control

Security Awareness Training produces behavioral outcomes (users do not click phishing links) that appear identical to those of a Preventive Technical control (a spam filter that blocks phishing emails). The classification difference is **enforcement mechanism**:

- A spam filter enforces the prevention automatically, regardless of user intent or knowledge.
- Security Awareness Training relies on the user applying learned behavior voluntarily, governed by policy and disciplinary consequence — not by automated enforcement.

This makes it an **Administrative** control: it governs human behavior through education and policy, not through a technical mechanism that operates independently of human decisions.

### Compensating Controls: Definition and Audit Acceptability

A **Compensating Control** is a substitute measure applied when the primary required control cannot be implemented due to a legitimate technical or business constraint. It is fundamentally different from a mitigating control:

- A **mitigating control** reduces the severity of a risk but does not replace the missing primary control for compliance purposes.
- A **compensating control** is formally accepted by the auditor as a substitute for the primary requirement, provided it meets an equivalent risk-reduction standard.

For a compensating control to be accepted by a regulatory auditor, it must:
1. Meet the intent of the original requirement.
2. Provide a similar level of defense.
3. Be above and beyond other existing controls.
4. Be commensurate with the risk of the compensated vulnerability.

A compensating control that merely acknowledges the risk without reducing it will be rejected.
