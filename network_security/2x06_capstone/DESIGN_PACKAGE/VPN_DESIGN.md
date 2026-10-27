# LogiCorp Gateway - VPN Architecture Design

**Prepared by:** IronShield Consulting
**Date:** 2026-10-27
**Classification:** Confidential

---

## 1. Overview

Wireguard VPN provides encrypted tunnels for all administrative and sensitive service access to the LogiCorp Gateway. This eliminates the exposure of SSH and FTP to the public internet.

---

## 2. Technology Selection: Wireguard

| Criteria | Wireguard | OpenVPN | Decision |
|----------|-----------|---------|----------|
| Codebase | ~4,000 lines | ~100,000 lines | Wireguard (smaller attack surface) |
| Performance | Kernel space | Userspace | Wireguard (faster) |
| Cryptography | Curve25519, ChaCha20, Poly1305 | Configurable (risk of weak config) | Wireguard (modern, fixed) |
| Stealth | Silent to unauthenticated packets | Responds to probes | Wireguard (harder to fingerprint) |
| Configuration | ~10 lines | ~50+ lines | Wireguard (simpler) |

---

## 3. Topology

```
                    INTERNET
                       |
                       | (UDP 51820 - Wireguard)
                       |
              +--------+--------+
              |  LogiCorp GW    |
              |  eth0: WAN IP   |
              |  wg0: 10.200.0.1|
              +---------+-------+
                        |
                   VPN Tunnel
                   (Encrypted)
                        |
           +------------+------------+
           |                         |
    +------+------+          +-------+------+
    | IT Admin    |          | Finance User |
    | 10.200.0.2  |          | 10.200.0.3   |
    | SSH Access  |          | FTP Access   |
    +-------------+          +--------------+
```

---

## 4. IP Addressing Scheme

| Entity | VPN IP | Role | AllowedIPs |
|--------|--------|------|------------|
| Gateway (Server) | 10.200.0.1/24 | VPN endpoint, gateway | N/A (server) |
| IT Admin (Client 1) | 10.200.0.2/32 | System administration | 10.200.0.0/24 |
| Finance User (Client 2) | 10.200.0.3/32 | FTP file transfers | 10.200.0.0/24 |

**Subnet:** 10.200.0.0/24 (RFC 1918 private range, 254 usable hosts)

---

## 5. Cryptographic Architecture

### Key Management

Each endpoint has a unique keypair:

| Endpoint | Private Key File | Public Key | Storage |
|----------|-----------------|------------|---------|
| Server | /etc/wireguard/server_private | Shared with clients | Gateway, mode 0600 |
| IT Admin | client_private (local) | Shared with server | Admin workstation |
| Finance | finance_private (local) | Shared with server | Finance workstation |

### Key Generation Process

```bash
# Server keypair
wg genkey | tee server_private | wg pubkey > server_public

# Client keypair
wg genkey | tee client_private | wg pubkey > client_public
```

**Security:** Private keys never transit the network. Only public keys are exchanged.

---

## 6. Server Configuration (wg0.conf)

```ini
[Interface]
Address = 10.200.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key>

# IT Admin
[Peer]
PublicKey = <it_admin_public_key>
AllowedIPs = 10.200.0.2/32

# Finance User
[Peer]
PublicKey = <finance_public_key>
AllowedIPs = 10.200.0.3/32
```

### Configuration Notes:
- **ListenPort 51820**: Standard Wireguard port, opened in firewall
- **AllowedIPs /32**: Each peer restricted to their assigned IP (cryptokey routing)
- **No Endpoint on server**: Clients initiate connections; server responds

---

## 7. Client Configurations

### IT Admin (client.conf)

```ini
[Interface]
Address = 10.200.0.2/24
PrivateKey = <it_admin_private_key>

[Peer]
PublicKey = <server_public_key>
Endpoint = <gateway_public_ip>:51820
AllowedIPs = 10.200.0.0/24
PersistentKeepalive = 25
```

### Finance User (finance.conf)

```ini
[Interface]
Address = 10.200.0.3/24
PrivateKey = <finance_private_key>

[Peer]
PublicKey = <server_public_key>
Endpoint = <gateway_public_ip>:51820
AllowedIPs = 10.200.0.0/24
PersistentKeepalive = 25
```

### Configuration Notes:
- **AllowedIPs 10.200.0.0/24**: Only VPN subnet traffic is routed through the tunnel (split tunneling)
- **PersistentKeepalive 25**: Maintains tunnel through NAT devices (sends keepalive every 25 seconds)

---

## 8. Access Control Matrix

| Source | Destination | Service | Port | Permitted |
|--------|-------------|---------|------|-----------|
| IT Admin (10.200.0.2) | Gateway (10.200.0.1) | SSH | 22 | YES |
| IT Admin (10.200.0.2) | Gateway (10.200.0.1) | FTP | 21 | YES |
| Finance (10.200.0.3) | Gateway (10.200.0.1) | FTP | 21 | YES |
| Finance (10.200.0.3) | Gateway (10.200.0.1) | SSH | 22 | YES |
| Internet (any) | Gateway (WAN IP) | SSH | 22 | **NO** |
| Internet (any) | Gateway (WAN IP) | FTP | 21 | **NO** |
| Internet (any) | Gateway (WAN IP) | Wireguard | 51820 | YES |

---

## 9. FTP over VPN Strategy

### Problem
FTP transmits credentials in cleartext. The Finance department requires FTP for business operations.

### Solution
Tunnel FTP through the Wireguard VPN:
1. FTP service binds to all interfaces but firewall restricts access to VPN interface only
2. Finance users connect to FTP via VPN IP (10.200.0.1)
3. All FTP traffic is encrypted within the Wireguard tunnel
4. Passive mode ports (40000-40100) also restricted to VPN

### Result
- FTP credentials are encrypted in transit (via VPN tunnel)
- FTP service is invisible from the public internet
- No application changes required for Finance department

---

## 10. Wireguard Stealth Properties

Wireguard has a unique security property: it does not respond to unauthenticated packets. This means:

- Port scanners see UDP 51820 as "closed" or "filtered"
- No handshake response without valid public key
- No version disclosure
- No protocol fingerprinting possible

This makes the VPN endpoint extremely resistant to reconnaissance.

---

## 11. Persistence

```bash
# Enable Wireguard at boot
systemctl enable wg-quick@wg0
```

The VPN tunnel will automatically establish on system restart.
