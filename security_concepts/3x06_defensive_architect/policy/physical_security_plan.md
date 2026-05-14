# Physical & Human Security Plan — Nexus Financial

**Document Reference:** NX-SEC-PSP-001
**Version:** 1.0
**Author:** Interim CISO
**Scope:** WeWork office premises, server room "The Core", all personnel

---

## Executive Summary

Nexus Financial's physical security posture is critically deficient. The office environment — a shared co-working space with an open floor plan, no reception, a propped server room door, visible credentials on a whiteboard, and unlocked workstations — represents an attack surface that requires no technical sophistication to exploit. An untrained visitor with 60 seconds of unsupervised access can compromise the company. This plan addresses these vulnerabilities in three phases: immediate zero-cost actions, short-term low-cost measures, and longer-term structural controls.

---

## Immediate Actions (Day 1 — Zero Cost)

### Action 1: Erase the Whiteboard — NOW

**Finding:** Wi-Fi Guest password, staging database password, and CEO's personal credentials are written in permanent marker on an office whiteboard visible to all occupants and visitors.

**Action:** Erase completely before this document is finished. Use whiteboard cleaner or isopropyl alcohol for permanent marker removal.

**Policy established immediately:** No passwords, credentials, PINs, or access codes may be written on any shared surface (whiteboards, sticky notes, paper on desks). This is a zero-tolerance policy effective immediately. Credentials are stored only in the approved password manager (see Access Control Policy).

**Consequence:** First violation — written warning. Second violation — termination.

---

### Action 2: Close the Server Room Door

**Finding:** The biometric lock on "The Core" server room is bypassed by a fire extinguisher propping the door open. Physical access to production hardware is unrestricted.

**Immediate action:**
1. Remove the fire extinguisher. Close and lock the door immediately.
2. Address the AC problem through legitimate channels: contact WeWork facilities management to repair the AC unit. If the server room temperature is genuinely dangerous, request an emergency portable AC unit (rental cost: approximately $50/day — justified against the cost of a physical breach).
3. Until AC is repaired, implement a 15-minute check rotation where an authorized staff member opens the door briefly to ventilate, then relocks it. This is not ideal but is infinitely better than a permanently open door.

---

### Action 3: Enforce Workstation Lock Policy — Immediately

**Finding:** 80% of MacBooks are left unlocked when employees leave their desks.

**Immediate action:** Send company-wide message within the hour: **"All workstations must be locked immediately when leaving your desk. No exceptions."**

**Technical enforcement:** Enable automatic lock after 2 minutes of inactivity on all MacBooks via MDM (if MDM exists) or via System Preferences → Lock Screen. If no MDM: walk desk-to-desk today and configure this manually on each machine.

**Physical enforcement:** Any staff member who observes an unlocked, unattended workstation is authorized and expected to lock it. This is not snitching — it is a company survival requirement.

---

### Action 4: Revoke Generic Keycards — Audit Today

**Finding:** All developers use the same generic keycard. A box of unlabeled spare cards sits under the Office Manager's desk.

**Immediate action:**
1. Collect and destroy all spare cards from the box under the Office Manager's desk.
2. Document every person who currently holds a keycard (name, card ID if available, date issued).
3. Block all generic cards that cannot be attributed to a named individual.
4. Issue temporary named access credentials to affected employees today.

---

## Short-Term Actions (Days 2–5 — Low Cost)

### Action 5: Visitor Access Control

**Finding:** No receptionist. The iPad check-in is broken. The delivery driver who filmed a TikTok inside "The Core" was never challenged.

**Implementation:**
- Designate one employee per day as "Office Security Anchor" — responsible for challenging any unknown person in the office and escorting all non-employees.
- Until a formal visitor management system is in place, use a physical visitor log (paper, pen) at the entrance: Name, Company, Host Employee, Time In, Time Out, Purpose.
- Post a sign at the entrance (print today): **"All visitors must sign in and be escorted at all times. Unescorted visitors will be asked to leave."**
- Contact WeWork management to repair the iPad visitor system and request that WeWork front desk staff enforce the sign-in requirement.

**Cost:** $0 (paper log) to $20 (printed sign, paper logbook).

---

### Action 6: Server Room Access Restriction

**Finding:** The server room biometric lock is present but bypassed. No access log exists. Unauthorized individuals (delivery driver) have been observed inside.

**Implementation:**
- Re-activate the biometric lock. Enroll only authorized personnel: CTO, Lead Developer (for emergency restart), and the interim CISO.
- Enable any existing access logging capability on the biometric system.
- If the biometric lock has no logging: purchase a $40 USB door alarm as an interim alert mechanism until a proper access log is deployed.
- Post a sign on the door: **"RESTRICTED ACCESS — Authorized Personnel Only. Trespass will result in immediate removal and law enforcement notification."**
- Brief all WeWork staff (through their facility manager) that this room is restricted and any delivery or maintenance personnel found inside should be immediately reported.

**Cost:** $0–$40 (door alarm) + $20 (signage).

---

### Action 7: Physical Cable and Port Security

**Finding:** Network cables are described as "spaghetti." Several unused switch ports are live, representing unauthorized network access points.

**Implementation:**
- Document every active network cable and the device it connects to.
- Disable all unused switch ports (technical implementation in `network_defense.sh`).
- Use colored cable management labels to identify cable ownership.
- Lock the network switch in a secured panel inside the server room — currently accessible to anyone who enters.

**Cost:** $20–$50 (cable labels, velcro ties).

---

### Action 8: MDM Deployment for MacBooks

**Finding:** 80% of unlocked workstations. No centralized device management.

**Implementation:**
- Deploy Apple Business Manager + MDM solution (Jamf Pro, Kandji, or free tier of Mosyle for startups). Most offer a 30-day trial.
- MDM enables: automatic screen lock enforcement, FileVault disk encryption enforcement, remote wipe capability, software inventory.
- Priority MDM policies to deploy on Day 2: automatic lock at 2 minutes, FileVault encryption enabled on all drives, screen lock required on wake.

**Cost:** $0 (trial) to $6–8/device/month at scale.

---

## Long-Term Actions (Post-Audit, Weeks 2–8)

### Action 9: Dedicated Secure Office Space

**Finding:** A shared co-working space (WeWork) is not an appropriate environment for a FinTech company processing financial data at IPO stage. The shared physical environment cannot be controlled.

**Recommendation:** Budget for dedicated, private office space with controlled access by Q2. The cost of a WeWork membership at IPO stage is comparable to a small private office, with significantly greater physical security control.

---

### Action 10: Formal Physical Security Policy

**Finding:** No physical security policy exists.

**Implementation:** After the immediate 5-day window, formalize the measures in this plan into a signed Physical Security Policy document covering: clean desk policy, visitor management, keycard issuance and revocation, server room access, device encryption, and media handling.

---

## The Delivery Driver TikTok Incident — Handling Protocol

### What Happened

An unauthorized third-party delivery contractor gained unsupervised access to the production server room, filmed the interior (including visible equipment, cable layout, and potentially network architecture), and posted publicly to social media. This is simultaneously a physical security failure and a potential intelligence-gathering event.

### Immediate Response

1. **Preserve evidence:** Screenshot and archive the TikTok video before any takedown request. The video is evidence.
2. **Identify the individual:** Contact the delivery company with the time of delivery and request identification of the driver.
3. **Assess what was visible:** Review the video content. Identify whether any sensitive information (IP addresses on screens, cable labels, server model numbers, security camera positions) is visible.
4. **Legal notification:** If sensitive information is visible in the video, notify legal counsel immediately. A formal takedown request under the platform's terms of service may be warranted. If the video discloses trade secrets or security architecture, a cease-and-desist may be appropriate.
5. **Incident documentation:** This is a confirmed physical security incident. Document it per the Incident Response Plan.

### Structural Response (Prevents Recurrence)

- No delivery personnel enter the building unescorted. All deliveries are accepted at the WeWork front desk or a designated reception point outside restricted areas.
- The server room door is closed and locked. No exceptions. A delivery driver will never again be in a position to film inside "The Core."
- The visitor policy (Action 5) ensures all non-employees are escorted and their presence is logged.

### Training Component

The incident is used as the opening case study in the mandatory security awareness training session (scheduled for Day 3):

- **Message to staff:** "A delivery driver filmed our servers. We do not know what he captured. This is the consequence of an unlocked door and no visitor policy. Every person in this room is responsible for physical security."
- No blame assigned to individuals (cultural sensitivity for a startup). Blame assigned to the *absence of policy*.
- Training outcome: every employee knows they are authorized — and expected — to challenge an unknown unescorted person in the office with: *"Hi, who are you here to see? Let me get them for you."*

---

## Physical Security Checklist — Day 5 (Audit Day)

| Item | Status | Evidence |
|------|--------|---------|
| Whiteboard cleared of all credentials | ✅ | Photo |
| Server room door locked | ✅ | Physical inspection |
| Server room access log active | ✅ | Log printout |
| Workstation auto-lock at 2 min enforced | ✅ | MDM policy screenshot |
| Unused network switch ports disabled | ✅ | Switch config export |
| Visitor log in use | ✅ | Physical log |
| Spare keycard box destroyed | ✅ | Witness attestation |
| Security awareness training completed | ✅ | Attendance record |
