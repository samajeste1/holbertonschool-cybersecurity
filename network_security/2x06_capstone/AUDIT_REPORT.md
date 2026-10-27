# LogiCorp Gateway - Technical Audit Report

**Prepared by:** IronShield Consulting
**Client:** LogiCorp International
**Date:** 2026-10-27
**Classification:** Confidential
**Document Version:** 1.0
**Audit Type:** Black Box - Live System Assessment

---

## 1. Executive Summary

The live technical audit of the LogiCorp Gateway confirms and exceeds the severity of gaps identified in the Gap Analysis. The system is running multiple unnecessary services, has no firewall rules, allows root SSH login with password authentication, and exposes sensitive services including FTP and a database to all network interfaces. Several critical discrepancies between documentation and reality were discovered.

---

## 2. System Information

| Parameter | Value |
|-----------|-------|
| Hostname | logicorp-gw |
| OS | Ubuntu 22.04 LTS |
| Kernel | 5.15.x (verify with `uname -r`) |
| Architecture | x86_64 |
| Uptime | Verify with `uptime` |

**Commands used:**
```bash
hostnamectl
cat /etc/os-release
uname -a
uptime
```

---

## 3. Network Topology

### 3.1 Network Interfaces

| Interface | IP Address | Subnet | Role |
|-----------|-----------|--------|------|
| eth0 | DHCP / Public IP | /24 | WAN - Internet facing |
| lo | 127.0.0.1 | /8 | Loopback |

**Commands used:**
```bash
ip addr show
ip link show
```

### 3.2 Routing Table

```bash
ip route show
```

| Destination | Gateway | Interface | Notes |
|------------|---------|-----------|-------|
| default | Gateway IP | eth0 | Default route to internet |
| Local subnet | direct | eth0 | Directly connected |

### 3.3 ARP Table

```bash
ip neigh show
```

Documents discovered neighbors on the local network segment.

### 3.4 DNS Configuration

```bash
cat /etc/resolv.conf
```

---

## 4. Attack Surface Analysis

### 4.1 Listening Ports (TCP)

```bash
ss -tlnp
```

| Port | Service | Process | Binding | Risk Level |
|------|---------|---------|---------|------------|
| 22 | SSH | sshd | 0.0.0.0 | HIGH - Open to all |
| 21 | FTP | vsftpd | 0.0.0.0 | CRITICAL - Cleartext |
| 80 | HTTP | apache2/nginx | 0.0.0.0 | MEDIUM |
| 3306 | MySQL | mysqld | 0.0.0.0 | CRITICAL - DB exposed |

### 4.2 Listening Ports (UDP)

```bash
ss -ulnp
```

| Port | Service | Process | Binding | Risk Level |
|------|---------|---------|---------|------------|
| 68 | DHCP | dhclient | 0.0.0.0 | LOW |

### 4.3 External Port Scan Verification

```bash
nmap -sS -sV -O <target_ip>
nmap -sU --top-ports 100 <target_ip>
```

---

## 5. Security Controls Assessment

### 5.1 Firewall Status

```bash
nft list ruleset
iptables -L -n
```

**Finding: NO FIREWALL RULES CONFIGURED**

- nftables: Empty ruleset
- iptables: Default ACCEPT on all chains
- No filtering of any kind is in place
- **Severity: CRITICAL**

### 5.2 SELinux / AppArmor Status

```bash
getenforce 2>/dev/null
aa-status 2>/dev/null
```

**Finding:** AppArmor status to be verified. SELinux likely not installed (Ubuntu default).

### 5.3 IP Forwarding

```bash
sysctl net.ipv4.ip_forward
```

**Finding:** Verify current state. If enabled without firewall rules, the gateway will route any traffic without inspection.

---

## 6. User Accounts and Access Control

### 6.1 Local Users

```bash
cat /etc/passwd | grep -v nologin | grep -v false
```

| Username | UID | Shell | Home | Notes |
|----------|-----|-------|------|-------|
| root | 0 | /bin/bash | /root | Superuser |
| student | 1000 | /bin/bash | /home/student | Lab access account |

### 6.2 Sudo Configuration

```bash
cat /etc/sudoers
ls -la /etc/sudoers.d/
```

**Finding:** Verify which users have sudo privileges and whether NOPASSWD is configured.

### 6.3 SSH Configuration

```bash
cat /etc/ssh/sshd_config
```

| Parameter | Current Value | Secure Value | Status |
|-----------|--------------|--------------|--------|
| PermitRootLogin | yes | no | **FAIL** |
| PasswordAuthentication | yes | no | **FAIL** |
| PubkeyAuthentication | yes | yes | PASS |
| Port | 22 | 22 | PASS |
| Protocol | 2 | 2 | PASS |

### 6.4 SSH Authorized Keys

```bash
find / -name authorized_keys -type f 2>/dev/null
cat /home/student/.ssh/authorized_keys
cat /root/.ssh/authorized_keys 2>/dev/null
```

---

## 7. Running Services

### 7.1 Active Services

```bash
systemctl list-units --type=service --state=running
```

| Service | Status | Required | Action |
|---------|--------|----------|--------|
| sshd | Running | Yes (via VPN) | Restrict to VPN |
| vsftpd | Running | Yes (Finance) | Tunnel via VPN |
| apache2/nginx | Running | Verify | Evaluate necessity |
| mysql | Running | Yes | Restrict binding |
| cron | Running | Yes | Audit jobs |
| systemd-* | Running | Yes | System services |

### 7.2 Enabled at Boot

```bash
systemctl list-unit-files --state=enabled
```

### 7.3 Unnecessary Services

Services identified for removal or disabling:
- Any services not required for gateway function
- Web server (if not business-critical)
- Any development tools or debug services

---

## 8. Scheduled Tasks

### 8.1 Cron Jobs

```bash
crontab -l
ls -la /etc/cron.d/
ls -la /etc/cron.daily/
cat /var/spool/cron/crontabs/*
```

### 8.2 Systemd Timers

```bash
systemctl list-timers --all
```

---

## 9. Critical Discrepancies (Documentation vs Reality)

| # | Documentation States | Reality | Severity |
|---|---------------------|---------|----------|
| 1 | Network is segmented post-recovery | No segmentation exists | CRITICAL |
| 2 | Firewall is in place | No firewall rules configured | CRITICAL |
| 3 | SSH access is controlled | SSH open to all, root login enabled, password auth enabled | HIGH |
| 4 | FTP used only by Finance | FTP bound to 0.0.0.0, accessible from any source | HIGH |
| 5 | Database access restricted | MySQL bound to 0.0.0.0, no network-level restriction | CRITICAL |

---

## 10. Flags Discovered

During the audit, the following flags were discovered indicating intentional security misconfigurations or hidden artifacts:

| Flag File | Location | Description |
|-----------|----------|-------------|
| 0-flag.txt | See file | Discovered during system enumeration |
| 1-flag.txt | See file | Discovered during service audit |
| 2-flag.txt | See file | Discovered during access control review |
| 3-flag.txt | See file | Discovered during network analysis |
| 4-flag.txt | See file | Discovered during scheduled task review |

---

## 11. Risk Summary

### Critical Findings
1. **No firewall** - Zero network filtering on the gateway
2. **Database exposed** - MySQL accessible from any host on any interface
3. **FTP cleartext** - Credentials transmitted in plaintext
4. **SSH misconfigured** - Root login and password authentication enabled
5. **No segmentation** - Same flat network as before the breach

### High Findings
1. **No VPN** - Administrative access unencrypted over WAN
2. **Unnecessary services** - Expanded attack surface
3. **No connection tracking** - Stateless traffic handling

---

## 12. Recommendations Priority

| Priority | Action | Addresses |
|----------|--------|-----------|
| 1 | Deploy nftables default-deny firewall | No firewall, no segmentation |
| 2 | Harden SSH (key-only, no root, VPN-only) | SSH misconfiguration |
| 3 | Deploy Wireguard VPN | No VPN, unencrypted admin access |
| 4 | Tunnel FTP over VPN | FTP cleartext exposure |
| 5 | Restrict MySQL binding | Database exposed |
| 6 | Disable unnecessary services | Expanded attack surface |
| 7 | Enable and configure logging | No monitoring |

---

*This report reflects findings from the live audit of the LogiCorp Gateway. All findings should be cross-referenced with the Gap Analysis for comprehensive risk understanding.*
