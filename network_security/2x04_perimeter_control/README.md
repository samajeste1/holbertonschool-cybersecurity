# Perimeter Control: The Iron Bastion

## Description

This project transforms a vulnerable Linux server into a hardened secure gateway using Zero Trust Architecture principles. It implements three critical layers of defense:

1. **Filtering (Firewall)** - Default deny policy using nftables
2. **Tunneling (VPN)** - Wireguard VPN to restrict SSH access
3. **Routing (NAT)** - Masquerading for VPN client internet access

## Environment

| Parameter   | Value          |
|-------------|----------------|
| VM          | Multipass      |
| Target Host | acme-gw01      |
| Username    | engineer       |
| Auth Method | engineer2026!  |

## Tools

- **Firewall:** nftables
- **VPN:** wireguard, wireguard-tools
- **Network:** ip, ss, ping
- **System:** systemctl, sysctl

## Files

| File | Description |
|------|-------------|
| `0-audit.sh` | Audit listening ports and associated processes |
| `1-install.sh` | Install nftables and wireguard |
| `2-panic.sh` | Dead man's switch to prevent firewall lockouts |
| `skeleton.conf` | nftables firewall configuration |
| `6-deploy.sh` | Deploy and apply firewall rules |
| `7-keygen.sh` | Generate Wireguard keypairs |
| `wg0.conf` | Wireguard server configuration |
| `client.conf` | Wireguard client configuration |
| `11-verify.sh` | Verify VPN handshake |
| `12-forward.sh` | Enable kernel IP forwarding |

## Author

samajeste1
