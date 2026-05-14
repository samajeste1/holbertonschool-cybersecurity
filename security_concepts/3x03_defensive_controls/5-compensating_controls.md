# Task 5: Compensating Controls

## Context

BioHealth's genomics lab contains an MRI machine running Windows XP Embedded. The device cannot be replaced or updated — it is a specialized medical instrument whose manufacturer has not released a Windows 10/11 compatible firmware. Windows XP reached end-of-life in April 2014. It receives no security patches, and known vulnerabilities (including EternalBlue/MS17-010, exploited in WannaCry) are permanently unmitigated on this platform.

A patch recommendation is not applicable. A replacement recommendation is not feasible within the 90-day window. A Compensating Control is required.

---

## Compensating Control Design: Network Isolation Architecture

### Primary Compensating Control — Hard Network Segmentation (VLAN Isolation)

**Rationale:** The Windows XP device's vulnerabilities are network-exploitable. An attacker must be able to reach the device over the network to exploit them. Removing network reachability removes the attack surface, without touching the device.

**Implementation:**
- Place the MRI machine on a dedicated, isolated VLAN with no routing to any other network segment (production LAN, research database VLAN, or internet).
- Configure the upstream switch with an explicit ACL (Access Control List) that:
  - Permits only the specific traffic required for device operation (e.g., DICOM protocol to the authorized imaging workstation on a separate, controlled VLAN).
  - Denies all other inbound and outbound traffic, including ICMP, SMB (port 445), RDP (port 3389), and all internet-bound traffic.
- Verify the isolation with a network penetration test (internal scan from adjacent VLANs confirming zero reachability).

**Why this satisfies the compensating control standard:**
- It meets the *intent* of patching (preventing exploitation of known vulnerabilities) through an alternative mechanism.
- It provides an *equivalent level of defense*: an unpatched vulnerability that is unreachable over the network cannot be remotely exploited.
- It is *above and beyond* existing controls (no segmentation currently exists).
- It is *commensurate with the risk*: EternalBlue-class vulnerabilities are wormable; hard segmentation is a proportionate response.

**Estimated cost:** 0–500 EUR (switch reconfiguration, no new hardware required if managed switches are already deployed).

---

### Supporting Compensating Control — Dedicated Imaging Workstation with Strict ACL

**Implementation:**
- The only authorized communication path from the MRI VLAN goes to a single, dedicated imaging workstation running a supported OS (Windows 10/11).
- This workstation is not domain-joined, has no internet access, and runs only the DICOM imaging software required to receive MRI output.
- All other traffic from the MRI VLAN — including to the research database and to the general corporate LAN — is blocked at the network layer.
- The imaging workstation acts as a data diode: MRI data flows out, nothing flows in to the XP device.

---

### Supporting Compensating Control — Physical Access Restriction

**Implementation:**
- The MRI machine's physical network port is documented and locked to a specific switch port.
- Unauthorized physical connections to the MRI machine's Ethernet port are prohibited by policy.
- The genomics lab containing the MRI is access-controlled (badge or key) with an access log.

---

### Supporting Compensating Control — Continuous Monitoring on Network Boundary

**Implementation:**
- Deploy a network tap or SPAN port on the switch handling the MRI VLAN.
- Feed traffic to the SIEM or an IDS rule set specifically monitoring for:
  - Any traffic exiting the MRI VLAN to unauthorized destinations.
  - SMB, RDP, or other exploit-relevant protocols originating from the XP device's IP.
  - Any new device appearing on the MRI VLAN (unauthorized connection).
- Alert threshold: any deviation from the baseline traffic profile generates an immediate alert.

---

## Compensating Control Summary

| Layer | Control | Function | Addresses |
|-------|---------|----------|-----------|
| Network | Hard VLAN isolation + ACL deny-all | Preventive | Remote exploitation of unpatched XP vulnerabilities |
| Network | Dedicated imaging workstation (data diode) | Preventive | Lateral movement from MRI VLAN |
| Physical | Badge access + port documentation | Preventive | Unauthorized physical network attachment |
| Monitoring | SIEM/IDS on VLAN boundary | Detective | Traffic anomalies, unauthorized connections |

## Regulatory Statement for CNIL Submission

*"BioHealth Inc. operates a medical imaging device (MRI) running Windows XP Embedded, which cannot be patched or replaced due to manufacturer hardware dependencies. In lieu of OS patching, BioHealth has implemented hard network segmentation isolating the device to a dedicated VLAN with an explicit deny-all ACL permitting only DICOM traffic to a single authorized imaging workstation. The device has no internet access, no access to the research data network, and no SMB or RDP exposure. Continuous monitoring is deployed on the network boundary. This architecture eliminates remote exploitability of known XP vulnerabilities and is assessed as providing equivalent protection to patching for network-based threat vectors. Physical access to the device is restricted and logged."*
