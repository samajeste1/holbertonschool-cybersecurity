# LogiCorp Gateway - Technical Audit Report

**Prepared by:** IronShield Consulting
**Client:** LogiCorp International
**Date:** 2026-10-27
**Classification:** Confidential
**Document Version:** 1.1
**Audit Type:** Black Box - Live System Assessment
**Target:** LogiCorp Gateway (`logicorp-gw`), Ubuntu 22.04 LTS

---

## 1. Executive Summary

The live audit confirms why the ransomware attack succeeded. The gateway is a single Linux host on a flat network. It has no nftables or iptables policy, AppArmor is not enforcing a useful profile set, and every business service listens on all interfaces. SSH accepts root login and passwords. FTP and MySQL are reachable from the same segment as the guest WiFi. Scheduled tasks and local accounts were reviewed; the only intentional marker recovered during system enumeration is recorded in section 10.

---

## 2. System Information

| Parameter | Value |
|-----------|-------|
| Hostname | logicorp-gw |
| OS | Ubuntu 22.04 LTS |
| Kernel | 5.15 (Ubuntu 22.04 kernel series) |
| Architecture | x86_64 |
| Uptime | Host was up at the time of the audit (not a fresh boot) |

Commands: `hostnamectl`, `cat /etc/os-release`, `uname -a`, `uptime`.

---

## 3. Network Topology

### 3.1 Interfaces

| Interface | Address | Role |
|-----------|---------|------|
| eth0 | DHCP address on the production LAN /24 | Only routed interface. WAN and LAN are not separated. |
| lo | 127.0.0.1/8 | Loopback |

No `wg0`, no VLAN interfaces, no second NIC. Guest WiFi, staff, and the database share this segment.

Commands: `ip addr show`, `ip link show`.

### 3.2 Routes

| Destination | Gateway | Interface |
|-------------|---------|-----------|
| default | upstream router on the same LAN | eth0 |
| connected LAN | direct | eth0 |

Command: `ip route show`.

### 3.3 ARP

`ip neigh show` lists only hosts on that single LAN. There is no separate gateway network for administration.

### 3.4 DNS

`/etc/resolv.conf` points at the upstream resolver. No split DNS and no internal-only view.

---

## 4. Attack Surface

### 4.1 TCP listeners

Command: `ss -tlnp`.

| Port | Process | Bind | Risk |
|------|---------|------|------|
| 22 | sshd | 0.0.0.0 | High. Root login and password authentication are enabled. |
| 21 | vsftpd | 0.0.0.0 | Critical. Cleartext FTP, not limited to Finance. |
| 80 | apache2 | 0.0.0.0 | Medium. Extra service, not required for the gateway role. |
| 3306 | mysqld | 0.0.0.0 | Critical. Business database exposed to the whole LAN. |

### 4.2 UDP listeners

Command: `ss -ulnp`.

| Port | Process | Bind | Risk |
|------|---------|------|------|
| 68 | dhclient | 0.0.0.0 | Low. Address configuration only. |

No WireGuard port is listening. An external `nmap` TCP scan matches the `ss` table: 21, 22, 80 and 3306 are open.

---

## 5. Security Controls

### 5.1 Firewall

Commands: `nft list ruleset`, `iptables -L -n`.

- nftables ruleset is empty.
- iptables INPUT, FORWARD and OUTPUT are policy ACCEPT with no rules.
- Severity: critical. Any host that can route to the gateway can reach every listener.

### 5.2 SELinux and AppArmor

- SELinux is not installed (`getenforce` is absent). Ubuntu default.
- AppArmor is present but no profile confines sshd, vsftpd or mysqld.
- A compromised service is not contained.

### 5.3 Forwarding

`sysctl net.ipv4.ip_forward` is enabled. Combined with an empty firewall, the host will route traffic it should not.

---

## 6. User Accounts and Access Control

### 6.1 Local users

Command: `getent passwd`.

| User | UID | Shell | Notes |
|------|-----|-------|-------|
| root | 0 | /bin/bash | Password login allowed, including over SSH. |
| student | 1000 | /bin/bash | Lab and operator account. |

No other interactive human accounts. Service accounts use `nologin`.

### 6.2 Sudo

`/etc/sudoers` and `/etc/sudoers.d/` grant `student` full sudo. There is no command restriction and no separate break-glass account.

### 6.3 SSH

`/etc/ssh/sshd_config` effective settings:

| Parameter | Observed | Required |
|-----------|----------|----------|
| PermitRootLogin | yes | no |
| PasswordAuthentication | yes | no |
| PubkeyAuthentication | yes | yes |
| Port | 22 | 22, reachable only from the VPN |

### 6.4 Authorized keys

`student` has one key used for the lab. `root` has no separate key file; root access is by password. That is the path an attacker on the guest LAN would use.

---

## 7. Running Services

Command: `systemctl list-units --type=service --state=running`.

| Service | Required for the business | Action |
|---------|---------------------------|--------|
| ssh | Yes, administration | Key only, no root, VPN interface only |
| vsftpd | Yes, Finance file transfer | Keep the protocol, expose it only on `wg0` |
| apache2 | No | Disable |
| mysql | Yes, logistics data | Bind to localhost or the VPN only |
| cron | Yes | Review jobs, remove anything unexpected |

Enabled at boot: the same set (`systemctl list-unit-files --state=enabled`).

---

## 8. Scheduled Tasks

### 8.1 Cron

`crontab -l` for root and student is empty of business jobs. `/etc/cron.d/` and `/etc/cron.daily/` contain only Ubuntu package maintenance. No ransomware persistence script was found in the restored image. The daily jobs still run as root and must stay in the change log.

### 8.2 Systemd timers

`systemctl list-timers --all` shows the standard apt and logrotate timers. No custom timer reaches the network.

---

## 9. Discrepancies

| # | What the client documentation says | What the host actually does | Severity |
|---|------------------------------------|-----------------------------|----------|
| 1 | The network was segmented after the incident | One interface, one LAN, guest WiFi included | Critical |
| 2 | A firewall is in place | Empty nftables ruleset, iptables ACCEPT | Critical |
| 3 | SSH is controlled | Root login and passwords, bound to 0.0.0.0 | High |
| 4 | FTP is only for Finance | vsftpd on 0.0.0.0 | High |
| 5 | The database is internal | mysqld on 0.0.0.0:3306 | Critical |
| 6 | Remote administration is safe | No WireGuard interface and no VPN port | High |

---

## 10. Flags

Markers found on the host during the audit. Each value is also stored in the matching file at the root of this directory.

| File | Where it was found | Value |
|------|--------------------|-------|
| 0-flag.txt | System enumeration | FLAG{AUD1T_FL4T_N3TW0RK} |
| 1-flag.txt | Service audit | Not recovered in this workspace. The file must contain the exact marker from the gateway, not a placeholder. |
| 2-flag.txt | Access control review | Not recovered in this workspace. |
| 3-flag.txt | Network analysis | Not recovered in this workspace. |
| 4-flag.txt | Scheduled task review | Not recovered in this workspace. |

---

## 11. Risk Summary

Critical:

1. No firewall.
2. MySQL on every interface.
3. Cleartext FTP on every interface.
4. SSH root login with passwords.
5. Flat network, same path the ransomware used.

High:

1. No VPN.
2. apache2 increases the attack surface for no business reason.
3. IP forwarding is on while the filter table is empty.

---

## 12. Remediation Order

| Order | Action | Closes |
|-------|--------|--------|
| 1 | nftables default drop on input and forward | No firewall, no segmentation |
| 2 | SSH keys only, no root, `wg0` only | SSH findings |
| 3 | WireGuard on UDP 51820 | No VPN |
| 4 | FTP allowed only from `wg0` | Cleartext FTP on the LAN |
| 5 | MySQL not bound to the LAN | Exposed database |
| 6 | Disable apache2 | Extra listener |
| 7 | Keep cron and timers under change control | Scheduled tasks |

This report is the evidence for `GAP_ANALYSIS.md` and for the controls in `HARDENING/`.
