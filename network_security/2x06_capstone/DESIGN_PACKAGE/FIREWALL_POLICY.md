# LogiCorp Gateway - Firewall Policy Specification

**Prepared by:** IronShield Consulting
**Date:** 2026-10-27
**Classification:** Confidential

---

## 1. Policy Overview

This document specifies the nftables firewall policy for the LogiCorp Gateway. The policy follows Zero Trust principles: deny all traffic by default, permit only explicitly authorized flows.

---

## 2. Default Policies

| Chain | Hook | Policy | Rationale |
|-------|------|--------|-----------|
| input | input | **DROP** | No unsolicited inbound traffic unless whitelisted |
| forward | forward | **DROP** | No transit traffic unless explicitly permitted |
| output | output | **ACCEPT** | Gateway-initiated traffic is trusted |

---

## 3. Zone Definitions

| Zone | Interface | Trust Level | Description |
|------|-----------|-------------|-------------|
| WAN | eth0 | Untrusted | Internet-facing interface |
| VPN | wg0 | Trusted | Wireguard VPN tunnel interface |
| LOOPBACK | lo | Trusted | Local process communication |

---

## 4. Input Chain Rules

Rules are ordered by match frequency for performance optimization.

| # | Match Criteria | Action | Justification |
|---|---------------|--------|---------------|
| 1 | `ct state established,related` | ACCEPT | Allow return traffic for existing connections |
| 2 | `iifname "lo"` | ACCEPT | Localhost communication (databases, caches) |
| 3 | `iifname "wg0" tcp dport 22` | ACCEPT | SSH only via VPN tunnel |
| 4 | `iifname "wg0" tcp dport 21` | ACCEPT | FTP control via VPN tunnel |
| 5 | `iifname "wg0" tcp dport 20` | ACCEPT | FTP data (active mode) via VPN |
| 6 | `iifname "wg0" tcp dport 40000-40100` | ACCEPT | FTP passive mode ports via VPN |
| 7 | `udp dport 51820` | ACCEPT | Wireguard VPN handshake (must be public) |
| 8 | `ip protocol icmp` | ACCEPT | Ping and Path MTU Discovery |
| 9 | (default policy) | DROP | Everything else is denied |

### Rule Ordering Rationale

1. **Connection tracking first**: Most packets belong to established connections. Matching these first avoids processing the entire rule chain for every packet.
2. **Loopback second**: High-frequency internal traffic.
3. **VPN services next**: Ordered by expected usage frequency.
4. **Wireguard port**: Required for VPN establishment from WAN.
5. **ICMP last**: Low frequency, needed for diagnostics.

---

## 5. Forward Chain Rules

| # | Match Criteria | Action | Justification |
|---|---------------|--------|---------------|
| 1 | `ct state established,related` | ACCEPT | Return traffic for forwarded connections |
| 2 | `iifname "wg0"` | ACCEPT | VPN clients can reach internal resources |
| 3 | (default policy) | DROP | No unauthorized transit traffic |

---

## 6. Output Chain Rules

| # | Match Criteria | Action | Justification |
|---|---------------|--------|---------------|
| 1 | (default policy) | ACCEPT | Gateway-originated traffic is trusted |

**Note:** Output filtering could be added in Phase 2 for egress control (preventing data exfiltration).

---

## 7. NAT Policy

### Postrouting (Source NAT)

| # | Match Criteria | Action | Justification |
|---|---------------|--------|---------------|
| 1 | `oifname "eth0"` | MASQUERADE | Rewrite VPN client source IPs to gateway's WAN IP |

**Purpose:** VPN clients use private IPs (10.200.0.0/24). When they access resources beyond the gateway, the source address must be rewritten to the gateway's public IP so return traffic can find its way back.

---

## 8. Complete nftables Configuration

```nft
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Connection tracking - most packets match here
        ct state established,related accept

        # Loopback - local process communication
        iifname "lo" accept

        # SSH - VPN only
        iifname "wg0" tcp dport 22 accept

        # FTP - VPN only (control + data + passive range)
        iifname "wg0" tcp dport 21 accept
        iifname "wg0" tcp dport 20 accept
        iifname "wg0" tcp dport 40000-40100 accept

        # Wireguard - must be publicly accessible for VPN establishment
        udp dport 51820 accept

        # ICMP - diagnostics and PMTU
        ip protocol icmp accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Return traffic for forwarded connections
        ct state established,related accept

        # VPN clients can route through gateway
        iifname "wg0" accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Source NAT for VPN clients accessing external resources
        oifname "eth0" masquerade
    }
}
```

---

## 9. Security Controls Summary

| Control | Implementation | NIST Reference |
|---------|---------------|----------------|
| Default Deny | DROP policy on input/forward | AC-3, SC-7 |
| Least Privilege | Only required ports open | AC-6 |
| Segmentation | VPN zone separated from WAN | SC-7(5) |
| Stateful Inspection | Connection tracking | SC-7(5) |
| Encryption | Services behind VPN tunnel | SC-8 |
| Defense in Depth | Multiple layers of control | SC-7(29) |
