# Patch Management Policy — NovaTech Solutions

**Document ID:** NVT-SEC-POL-002
**Version:** 1.0
**Effective Date:** 2025-01-20
**Owner:** Chief Information Security Officer (CISO)
**Classification:** INTERNAL

---

## 1. Purpose and Scope

### Purpose

This policy establishes the standards, procedures, and responsibilities for managing software patches and updates across all NovaTech Solutions production systems. It ensures that security vulnerabilities are addressed promptly while minimizing disruption to business operations.

### Scope

This policy applies to:

- All production servers and infrastructure managed by NovaTech
- All operating system packages (APT/DPKG managed)
- All third-party software deployed in production
- All personnel responsible for system administration and security

Out of scope:

- Development and staging environments (covered by separate policy)
- End-user workstations (covered by endpoint management policy)

---

## 2. Roles and Responsibilities

| Role | Responsibility |
|------|---------------|
| **CISO** | Policy approval, exception approval for Critical patches, compliance oversight |
| **Security Engineer** | Vulnerability monitoring, patch classification, emergency patch coordination |
| **System Administrator** | Patch testing, deployment execution, rollback procedures, system monitoring |
| **Application Owner** | Impact assessment, testing coordination, approval for application-layer patches |
| **Change Advisory Board (CAB)** | Review and approve non-emergency patches, post-incident reviews |

### Escalation Path

1. Security Engineer identifies vulnerability
2. System Administrator assesses impact and prepares patch
3. Application Owner approves deployment window
4. CAB approves (non-emergency) or CISO approves (emergency)
5. System Administrator deploys and monitors

---

## 3. Patch Classification

Patches are classified by severity to determine response timelines:

| Classification | Criteria | Response Time | Approval Required |
|---------------|----------|---------------|-------------------|
| **Critical** | Active exploitation in the wild, CVSS >= 9.0, remote code execution without authentication | 24 hours | CISO (emergency) |
| **High** | CVSS 7.0-8.9, authentication bypass, privilege escalation, data exposure | 72 hours | CAB (expedited) |
| **Medium** | CVSS 4.0-6.9, requires local access or authentication, denial of service | 14 days | CAB (standard) |
| **Low** | CVSS < 4.0, informational, hardening recommendations | 30 days | System Administrator |

### Automatic vs Manual

- **Automatic (unattended-upgrades):** Low and Medium security patches for non-blacklisted packages
- **Manual review required:** Critical and High patches, all blacklisted package updates

---

## 4. Update Schedule

### Automatic Security Updates

| Parameter | Value |
|-----------|-------|
| Package list refresh | Daily at 02:00 UTC |
| Security patch installation | Daily at 03:00 UTC |
| Maintenance window | 02:00 - 05:00 UTC |
| Automatic reboot (if required) | 04:00 UTC |
| Reboot condition | Only when no users are logged in |

### Manual Patch Cycles

| Cycle | Frequency | Scope |
|-------|-----------|-------|
| Security review | Weekly (Monday) | Review blacklisted package updates |
| Full patch cycle | Monthly (first Saturday) | All pending non-security updates |
| Emergency patches | As needed | Critical/High vulnerabilities |

---

## 5. Protected Packages

The following packages are excluded from automatic updates due to their critical role in production operations:

| Package | Reason | Review Frequency |
|---------|--------|-----------------|
| apache2, apache2-bin | Web server — downtime impacts e-commerce | Weekly |
| mysql-server, mysql-server-* | Database — schema compatibility risks | Weekly |
| nginx | Reverse proxy — configuration compatibility | Weekly |
| docker-ce | Container runtime — API compatibility | Monthly |

### Blacklist Management

- Blacklisted packages must be reviewed weekly for pending security updates
- Security updates for blacklisted packages must be applied within the classification timeline
- All blacklist additions/removals must be logged with justification

---

## 6. Exception Process

### Adding a Package Hold

1. System Administrator identifies the need for a hold (e.g., regression, compatibility issue)
2. Document the reason in `/var/log/package_holds.log`
3. Apply hold using `apt-mark hold <package>`
4. Notify Security Engineer within 24 hours
5. CAB review within 7 days

### Hold Limitations

- Maximum hold duration: 30 days
- Holds older than 14 days trigger automatic review notification
- CISO approval required for holds exceeding 30 days
- All holds must have a documented exit plan

### Emergency Exception

For Critical patches that cannot be applied due to compatibility:

1. CISO must approve the exception within 4 hours
2. Compensating controls must be documented and implemented
3. Fix timeline must be established (maximum 7 days)
4. Daily status reports to CISO until resolved

---

## 7. Emergency Patching

### Trigger Criteria

Emergency patching is initiated when:

- A Critical vulnerability is actively exploited in the wild
- CISA or vendor issues an emergency directive
- NovaTech security monitoring detects active exploitation attempts
- CISO declares a security emergency

### Emergency Procedure

1. **T+0 min:** Security Engineer confirms vulnerability and classifies as Critical
2. **T+15 min:** CISO notified and approves emergency patch
3. **T+30 min:** System Administrator prepares patch and backup
4. **T+45 min:** Patch applied to production with active monitoring
5. **T+60 min:** Verification and post-deployment testing
6. **T+24 hr:** Post-incident review and documentation

### Emergency Constraints

- Full system backup must be created before patching
- Rollback plan must be documented before deployment
- At least two engineers must be available during emergency patching
- All actions must be logged for audit purposes

---

## 8. Compliance and Auditing

### Monitoring

| Metric | Target | Measured |
|--------|--------|----------|
| Mean time to patch (Critical) | < 24 hours | Per incident |
| Mean time to patch (High) | < 72 hours | Per incident |
| Patch compliance rate | > 95% | Monthly |
| Automatic update success rate | > 99% | Monthly |
| Held package count | < 5 | Weekly |

### Audit Trail

All patch management activities are logged in:

- `/var/log/unattended-upgrades/unattended-upgrades.log` — Automatic updates
- `/var/log/unattended-upgrades/unattended-upgrades-dpkg.log` — Package operations
- `/var/log/dpkg.log` — All package state changes
- `/var/log/apt/history.log` — APT operations history
- `/var/log/package_holds.log` — Package hold registry
- System syslog (facility: daemon) — Unattended-upgrades events

### Compliance Reviews

- **Monthly:** Automated report of patch status across all systems
- **Quarterly:** CAB review of policy effectiveness, held packages, and exception history
- **Annually:** Full policy review and update by CISO

### Reporting

Monthly patch compliance reports are generated and distributed to:

- CISO (executive summary)
- System Administrators (technical details)
- CAB members (trend analysis)

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-20 | Security Engineering | Initial policy creation |

---

**Approved by:**

CISO, NovaTech Solutions

Date: 2025-01-20
