# Bastion Host Hardening Report

**Prepared for:** Chief Information Security Officer (CISO)
**Prepared by:** Security Engineering Team
**Date:** 2024-01-15
**Classification:** CONFIDENTIAL
**System:** Bastion Host — DMZ Gateway Server
**OS:** Ubuntu 20.04 LTS

---

## 1. Executive Summary

This report documents the comprehensive hardening of the bastion host designated for DMZ deployment at NovaTech Solutions. The server acts as the sole administrative gateway into the DMZ, requiring the highest level of security posture.

Starting from a default Ubuntu 20.04 installation with a Lynis hardening index of **62/100**, we applied 20+ security controls across five domains: kernel hardening, package minimization, privilege reduction, filesystem restrictions, and service minimization. The final Lynis hardening index reached **84/100**, representing a **+22 point improvement** and a significant reduction in attack surface.

The system is now recommended for DMZ deployment pending CISO sign-off.

---

## 2. Baseline Assessment

### Initial Lynis Audit Results

| Metric             | Value |
|--------------------|-------|
| Hardening Index    | 62    |
| Tests Performed    | 256   |
| Warnings           | 18    |
| Suggestions        | 45    |

### Key Findings at Baseline

- IPv4/IPv6 forwarding enabled (unnecessary for bastion role)
- ICMP redirects accepted on all interfaces
- No reverse path filtering enabled
- SYN flood protection disabled
- Development tools (gcc, make) installed
- Network diagnostic tools world-accessible
- 23 SUID binaries found (only 5 essential)
- /tmp, /var/tmp, /dev/shm mounted without restrictions
- 13 unnecessary services running (cups, avahi, bluetooth, etc.)
- Root account directly accessible
- No legal access banner configured

---

## 3. Hardening Measures Applied

### 3.1 Kernel Parameter Hardening

**Objective:** Reduce network-layer attack surface through sysctl tuning.

| Control | Parameter | Before | After | Risk Mitigated |
|---------|-----------|--------|-------|----------------|
| Disable IP forwarding | net.ipv4.ip_forward | 1 | 0 | Prevents use as router/pivot |
| Disable IPv6 forwarding | net.ipv6.conf.all.forwarding | 1 | 0 | Prevents IPv6 routing abuse |
| Block ICMP redirects (accept) | net.ipv4.conf.all.accept_redirects | 1 | 0 | Prevents route table poisoning |
| Block ICMP redirects (send) | net.ipv4.conf.all.send_redirects | 1 | 0 | Prevents MITM routing attacks |
| Reverse path filtering | net.ipv4.conf.all.rp_filter | 0 | 1 | Blocks IP spoofing |
| SYN cookies | net.ipv4.tcp_syncookies | 0 | 1 | Mitigates SYN flood DoS |
| Ignore broadcast pings | net.ipv4.icmp_echo_ignore_broadcasts | 0 | 1 | Prevents Smurf amplification |
| Ignore bogus ICMP errors | net.ipv4.icmp_ignore_bogus_error_responses | 0 | 1 | Reduces log noise from spoofed ICMP |
| Block source routing | net.ipv4.conf.all.accept_source_route | 1 | 0 | Prevents source routing bypass |

**Persistence:** All parameters written to `/etc/sysctl.d/99-hardening.conf` and applied via `sysctl -p`.

### 3.2 Package Minimization

**Objective:** Remove unnecessary software that could be leveraged by attackers.

| Action | Packages | Justification |
|--------|----------|---------------|
| Removed compilers | gcc, g++, make, build-essential | Prevents on-host malware compilation |
| Restricted network tools | nmap, tcpdump, netcat, ncat, wireshark | Moved to root-only (chmod 0750) |
| Audited LOLBins | python3, perl, curl, wget, socat | Flagged GTFOBins-capable binaries for monitoring |

**LOLBins Decision:** Python3 and curl retained (needed for operations) but flagged for enhanced monitoring. Socat and netcat restricted to root access only.

### 3.3 Privilege Reduction (SUID/SGID)

**Objective:** Minimize SUID binaries to reduce privilege escalation vectors.

| Binary | Decision | Reason |
|--------|----------|--------|
| /usr/bin/sudo | KEEP | Required for administrative access |
| /usr/bin/passwd | KEEP | Required for password changes |
| /usr/bin/su | KEEP | Required for user switching |
| /usr/bin/ping | KEEP | Required for network diagnostics |
| /usr/lib/openssh/ssh-keysign | KEEP | Required for SSH host-based auth |
| /usr/bin/mount | REMOVE | Admin can use sudo mount |
| /usr/bin/umount | REMOVE | Admin can use sudo umount |
| /usr/bin/newgrp | REMOVE | Not needed on server |
| /usr/bin/chsh | REMOVE | Not needed on server |
| /usr/bin/chfn | REMOVE | Not needed on server |
| /usr/bin/gpasswd | REMOVE | Admin can use sudo |
| /usr/bin/pkexec | REMOVE | GTFOBins high risk (CVE-2021-4034) |

**Result:** SUID binaries reduced from 23 to 5 (78% reduction).

### 3.4 Filesystem Hardening

**Objective:** Prevent code execution from world-writable directories.

| Mount Point | Options Applied | Purpose |
|-------------|----------------|---------|
| /tmp | noexec, nosuid, nodev | Block execution from temp directory |
| /var/tmp | bind to /tmp | Inherits /tmp restrictions |
| /dev/shm | noexec, nosuid, nodev | Block execution from shared memory |

**Persistence:** All mount options added to `/etc/fstab`.

### 3.5 Service Minimization

**Objective:** Disable unnecessary services to reduce listening ports and attack surface.

| Service | Description | Action |
|---------|------------|--------|
| cups, cups-browsed | Printing services | Disabled |
| avahi-daemon | mDNS/DNS-SD discovery | Disabled |
| bluetooth | Bluetooth stack | Disabled |
| snapd | Snap package manager | Disabled |
| postfix | Mail server | Disabled |
| rpcbind | RPC portmapper | Disabled |
| nfs-server | NFS file sharing | Disabled |
| ModemManager | Modem management | Disabled |
| accounts-daemon | User accounts GUI | Disabled |
| whoopsie | Error reporting | Disabled |
| kerneloops | Kernel error reporting | Disabled |
| apport | Crash reporting | Disabled |

**Essential services preserved:** sshd (remote access), nginx/apache2 (web serving if applicable).

### 3.6 Access Controls

| Control | Implementation | Purpose |
|---------|---------------|---------|
| Root account locked | `passwd -l root` | Enforce sudo for all admin actions |
| SSH root login disabled | `PermitRootLogin no` | Prevent direct root SSH access |
| Legal banner | `/etc/issue.net` via SSH Banner | Legal deterrent and prosecution basis |

---

## 4. Final Assessment

### Post-Hardening Lynis Audit Results

| Metric             | Baseline | Final | Change |
|--------------------|----------|-------|--------|
| Hardening Index    | 62       | 84    | +22    |
| Tests Performed    | 256      | 256   | 0      |
| Warnings           | 18       | 4     | -14    |
| Suggestions        | 45       | 12    | -33    |

### Improvement Breakdown by Domain

| Domain | Points Gained |
|--------|--------------|
| Kernel hardening | +6 |
| Package minimization | +4 |
| SUID reduction | +3 |
| Filesystem hardening | +4 |
| Service minimization | +3 |
| Access controls | +2 |

---

## 5. Remaining Recommendations

The following items were identified during the final audit but are outside the current hardening scope:

### Priority 1 — Implement Before Production

| Item | Description | Effort |
|------|------------|--------|
| auditd | Enable and configure Linux audit daemon for command logging | Medium |
| Intrusion detection | Deploy AIDE or OSSEC for file integrity monitoring | Medium |
| Log forwarding | Configure rsyslog to forward logs to SIEM | Low |

### Priority 2 — Implement Within 30 Days

| Item | Description | Effort |
|------|------------|--------|
| Process accounting | Enable acct for user activity tracking | Low |
| Log rotation | Configure logrotate for all custom logs | Low |
| Automatic updates | Enable unattended-upgrades for security patches | Low |
| Fail2ban | Deploy brute-force protection for SSH | Low |

### Priority 3 — Ongoing

| Item | Description |
|------|------------|
| Vulnerability scanning | Monthly Lynis audits with score tracking |
| Patch management | Weekly review of security advisories |
| Access reviews | Quarterly review of sudo privileges and user accounts |

---

## 6. Sign-off Checklist

| # | Control | Status | Verified By |
|---|---------|--------|-------------|
| 1 | Kernel parameters hardened (9 controls) | COMPLETE | Security Team |
| 2 | Unnecessary packages removed/restricted | COMPLETE | Security Team |
| 3 | LOLBins audited and documented | COMPLETE | Security Team |
| 4 | SUID binaries reduced to essential set | COMPLETE | Security Team |
| 5 | Temporary directories hardened (noexec) | COMPLETE | Security Team |
| 6 | Unnecessary services disabled (13 services) | COMPLETE | Security Team |
| 7 | Root account locked | COMPLETE | Security Team |
| 8 | SSH root login disabled | COMPLETE | Security Team |
| 9 | Legal banner configured | COMPLETE | Security Team |
| 10 | Lynis score improved (62 -> 84) | COMPLETE | Security Team |

---

**CISO Approval:**

- [ ] Approved for DMZ deployment
- [ ] Approved with conditions (see notes)
- [ ] Not approved — additional hardening required

**Signature:** ____________________________
**Date:** ____________________________
**Notes:** ____________________________
