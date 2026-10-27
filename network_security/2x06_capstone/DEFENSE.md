# LogiCorp Gateway - Technical Defense Document

**Prepared by:** IronShield Consulting
**Date:** 2026-10-27
**Classification:** Confidential
**Review Stage:** Senior Architect Challenge

---

## Challenge 1: Risk Acceptance - FTP over VPN

> "You kept FTP running, even tunneled over VPN. FTP is inherently insecure. Why not force the client to upgrade to SFTP?"

### Business Constraint Analysis

The Finance department relies on FTP for daily operations across 40 countries. Forcing an immediate migration to SFTP would require:

1. **Application changes**: All automated scripts and integrations that use FTP would need to be rewritten
2. **Client software updates**: Every Finance workstation across 40 countries needs new software or configuration
3. **User retraining**: Finance staff are trained on FTP workflows; SFTP has different tooling
4. **Testing period**: A parallel run period is needed to validate SFTP doesn't break business processes
5. **Coordination overhead**: 40 countries, multiple time zones, varying IT maturity levels

An immediate cutover carries a high risk of business disruption. The ransomware attack already caused 2 days of downtime. Causing additional downtime through a rushed migration would undermine client confidence in our engagement.

### Risk Mitigation Measures Implemented

While FTP is inherently insecure at the protocol level, we have implemented multiple compensating controls:

1. **VPN Encapsulation**: All FTP traffic (including cleartext credentials) is encrypted within the Wireguard tunnel using Curve25519/ChaCha20/Poly1305. The FTP session is never exposed to the network.

2. **Firewall Restriction**: FTP ports (21, 20, 40000-40100) are only accessible from the `wg0` VPN interface. The FTP service is invisible from the WAN.

3. **Authentication Gating**: Before a user can reach FTP, they must authenticate to the Wireguard VPN using their cryptographic keypair. This adds a strong authentication layer before the FTP authentication.

4. **Network Isolation**: Even if FTP credentials are compromised, the attacker cannot reach the FTP service without a valid VPN key.

### Residual Risk

- FTP credentials are still transmitted in cleartext **within** the VPN tunnel. If an endpoint is compromised (keylogger, memory dump), credentials can be captured.
- FTP has no integrity verification; file tampering is theoretically possible at the endpoint level.
- The FTP protocol itself has no protection against path traversal or other protocol-level vulnerabilities.

### Phase 2 Recommendation

We recommend a planned migration to SFTP within 90 days:

1. **Month 1**: Deploy SFTP alongside FTP, begin pilot with one country
2. **Month 2**: Migrate remaining countries in waves, with rollback capability
3. **Month 3**: Decommission FTP, update firewall rules to remove FTP ports

This gives Finance adequate time to adapt while maintaining security through the VPN tunnel.

---

## Challenge 2: Firewall Strategy - Lateral Movement Prevention

> "Explain your segmentation logic. How does it specifically prevent the lateral movement that caused the previous breach?"

### The Original Attack Path

In the ransomware incident, the attack followed this path:

```
Guest WiFi Device → [flat network, no firewall] → Database Server
```

There were zero barriers between an untrusted device and the most critical asset.

### Zone Definitions and Trust Levels

Our architecture defines four distinct trust zones:

| Zone | Trust Level | Policy | Rationale |
|------|-------------|--------|-----------|
| WAN | **Untrusted** | Default DENY, allow only Wireguard (UDP 51820) and ICMP | Internet traffic is hostile by default |
| Gateway | **Controlled** | Only gateway processes run here | Single purpose: routing, filtering, VPN termination |
| VPN | **Trusted** | Authenticated users via cryptographic keys | Only users with valid Wireguard keys can access |
| Loopback | **Internal** | Full access | Local process communication only |

### How Each Attack Step Is Now Blocked

**Step 1: Attacker connects to network**
- **Before**: Attacker on guest WiFi had full L3 access to all hosts
- **After**: The gateway firewall has `policy drop` on the input chain. No service is reachable from WAN except Wireguard (UDP 51820). Wireguard does not respond to unauthenticated packets, making it invisible to port scanners.

**Step 2: Attacker scans for services**
- **Before**: All ports on all hosts were reachable, nmap would find SSH, FTP, MySQL
- **After**: Port scan from WAN reveals nothing useful. SSH, FTP, and MySQL are only accessible from the VPN interface (`iifname "wg0"`). The attacker cannot even discover these services exist.

**Step 3: Attacker attempts lateral movement**
- **Before**: No firewall, free movement between all hosts
- **After**: The `forward` chain has `policy drop`. Only traffic from the VPN interface is forwarded. An attacker on the WAN cannot route packets to internal networks.

**Step 4: Attacker reaches the database**
- **Before**: MySQL bound to 0.0.0.0, accessible from any host
- **After**: MySQL is restricted to localhost (loopback). Even VPN users cannot directly connect to MySQL over the network.

### Defense in Depth Applied

Our solution implements multiple independent layers:

1. **Layer 1 - Network**: Default deny firewall at the gateway
2. **Layer 2 - Authentication**: VPN requires cryptographic key (not just password)
3. **Layer 3 - Transport**: All sensitive traffic encrypted in VPN tunnel
4. **Layer 4 - Service**: SSH hardened (no root, key-only)
5. **Layer 5 - Host**: Unnecessary services disabled, kernel hardened

If any single layer fails, the remaining layers still provide protection. The original infrastructure had zero layers.

---

## Challenge 3: Resilience - Single Point of Failure

> "The Gateway is still a Single Point of Failure. What happens if it goes down?"

### Scope Acknowledgment

High availability (HA) was explicitly out of scope for this engagement. The mandate was to harden the existing gateway against the confirmed attack vector (lateral movement), not to redesign the infrastructure for redundancy.

LogiCorp's immediate risk was a repeat breach. Our engagement addresses that risk. Availability is a separate risk domain.

### Current Risk Exposure

If the gateway fails:

| Impact | Severity | Duration |
|--------|----------|----------|
| VPN access lost | High | Until gateway restored |
| FTP unavailable | High | Until gateway restored |
| SSH admin access lost | High | Console access still available via Multipass/hypervisor |
| Internet routing lost | High | Until gateway restored |

**Mitigation factors already in place:**
- Firewall rules persist across reboots (`/etc/nftables.conf`, `systemctl enable nftables`)
- VPN starts automatically at boot (`systemctl enable wg-quick@wg0`)
- IP forwarding persists across reboots (`/etc/sysctl.conf`)
- SSH configuration persists (file-based)

This means a simple reboot (e.g., kernel update, power cycle) will restore full functionality automatically without manual intervention.

### Phase 2 High-Level Plan for HA

For a future engagement, we recommend:

**Option A: Active-Passive Failover**
- Deploy a secondary gateway with identical configuration
- Use keepalived (VRRP) for automatic IP failover
- Synchronize Wireguard configurations between nodes
- Estimated additional cost: 1 VM + configuration management

**Option B: Active-Active with Load Balancing**
- Deploy two gateways behind a load balancer
- Use DNS round-robin or dedicated LB appliance
- More complex but provides load distribution
- Estimated additional cost: 2 VMs + LB

### Cost-Benefit Analysis

| Factor | Current (Single) | Option A (Active-Passive) | Option B (Active-Active) |
|--------|-------------------|---------------------------|--------------------------|
| Infrastructure cost | 1 VM | 2 VMs | 3 VMs (2 GW + 1 LB) |
| Configuration complexity | Low | Medium | High |
| Recovery time (RTO) | Minutes (reboot) | Seconds (automatic failover) | Zero (seamless) |
| Maintenance burden | Low | Medium | High |

**Recommendation:** Option A (Active-Passive) provides the best balance of availability improvement versus cost and complexity. It should be the first priority of a Phase 2 engagement.

However, the current single-gateway architecture with automatic service recovery at boot provides acceptable availability for a logistics company that was previously running with zero security controls. The priority was correctly placed on preventing the next breach, not optimizing uptime.

---

## Summary of Engineering Trade-offs

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| Keep FTP (tunneled) | Security purity vs. business continuity | VPN encryption compensates; migration planned for Phase 2 |
| Default deny firewall | Convenience vs. security | Security is non-negotiable after a confirmed breach |
| SSH key-only via VPN | Accessibility vs. security | Eliminates two attack vectors (password brute-force, public SSH) |
| Single gateway | Availability vs. budget | Scope-appropriate; HA planned for Phase 2 |
| Output ACCEPT policy | Egress control vs. simplicity | Prioritized inbound protection; egress filtering in Phase 2 |
| ICMP allowed | Stealth vs. operational needs | PMTU discovery and diagnostics outweigh fingerprinting risk |

Each trade-off was made consciously, documented, and includes a Phase 2 remediation path. This is how mature security engineering works: perfect is the enemy of deployed.
