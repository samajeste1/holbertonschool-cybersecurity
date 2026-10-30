# Incident Response Procedure — Patch Management Failures

**Document ID:** NVT-SEC-IRP-003
**Version:** 1.0
**Effective Date:** 2025-01-20
**Owner:** Security Engineering Team
**Classification:** INTERNAL — On-Call Runbook

---

## 1. Detection Criteria

A patch-related incident is declared when ANY of the following occur after an automatic or manual update:

### Service Impact

- A monitored service fails health checks (HTTP 5xx, connection refused, timeout)
- Application error rate increases by more than 10% within 30 minutes of an update
- System monitoring alerts for service downtime (Nagios, Zabbix, or custom checks)

### System Impact

- System fails to boot after kernel update
- Package manager enters a broken state (dpkg lock, half-configured packages)
- Disk space exhaustion from cached packages

### Security Impact

- SSL/TLS errors appear after certificate-related package update
- Authentication failures after PAM or SSH package update
- Firewall rules disrupted after netfilter/iptables package update

### How to Confirm

```bash
# Check if an automatic update ran recently
cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -20

# Check dpkg log for recent changes
grep "$(date +%Y-%m-%d)" /var/log/dpkg.log | grep ' upgrade '

# Check if reboot occurred
last reboot | head -5
uptime
```

---

## 2. Initial Assessment (First 5 Minutes)

### Checklist

- [ ] **Identify the symptom:** What service or function is broken?
- [ ] **Check update logs:** Did an automatic update run in the last 6 hours?
- [ ] **Confirm timeline:** When did the problem start? When was the last update?
- [ ] **Assess severity:** Is this affecting customers? Is data at risk?
- [ ] **Declare incident level:**

| Level | Criteria | Response |
|-------|----------|----------|
| **SEV-1** | Customer-facing service down, data at risk | All hands, CISO notified |
| **SEV-2** | Service degraded, no data risk | On-call + backup engineer |
| **SEV-3** | Internal impact only, workaround available | On-call engineer |

### Quick Commands

```bash
# What services are down?
systemctl --failed

# What was updated recently?
grep ' upgrade ' /var/log/dpkg.log | tail -20

# Is the package manager healthy?
dpkg --audit
apt-get check

# Current system state
uptime
free -h
df -h
```

---

## 3. Diagnosis Steps

### Step 1: Identify When the Problem Started

```bash
# Check application logs for first error
journalctl --since "6 hours ago" | grep -i "error\|fail\|critical" | head -10

# Check Apache logs
tail -50 /var/log/apache2/error.log

# Check MySQL logs
tail -50 /var/log/mysql/error.log
```

### Step 2: Correlate with Update Timeline

```bash
# List all packages updated today
grep "$(date +%Y-%m-%d)" /var/log/dpkg.log | grep ' upgrade '

# Check unattended-upgrades log
grep "$(date +%Y-%m-%d)" /var/log/unattended-upgrades/unattended-upgrades.log

# Check apt history
cat /var/log/apt/history.log | tail -40
```

### Step 3: Identify the Culprit Package

Narrow down by domain:

| Symptom | Suspect Packages |
|---------|-----------------|
| Web server errors | apache2, libapache2-mod-*, php* |
| SSL/TLS errors | openssl, libssl*, ca-certificates, libcurl* |
| Database errors | mysql-server*, libmysql* |
| Authentication failures | libpam*, openssh-server, sssd |
| Network issues | iptables, netfilter*, iproute2 |
| DNS resolution | systemd-resolved, libnss*, dnsutils |

```bash
# Use the diagnostic script
./20-identify_bad_update.sh "YYYY-MM-DD HH:MM"
```

### Step 4: Verify the Culprit

```bash
# Check what changed in the package
apt-cache changelog <package> | head -30

# Check if the package has known issues
apt-cache showpkg <package>

# Test by checking the specific functionality
# Example for SSL: openssl s_client -connect localhost:443
```

---

## 4. Rollback Procedure

### Pre-Rollback Checklist

- [ ] Culprit package identified and confirmed
- [ ] Previous version number obtained from dpkg log
- [ ] Backup of current configuration created
- [ ] Rollback commands prepared and reviewed
- [ ] Second engineer available for verification

### Step-by-Step Rollback

```bash
# 1. Get the previous version
grep '<package_name>' /var/log/dpkg.log | grep ' upgrade ' | tail -1
# Note the old version (field before the arrow)

# 2. Downgrade the package
apt-get install -y --allow-downgrades <package>=<previous_version>

# 3. Verify the downgrade
dpkg -l <package> | grep '^ii'

# 4. Place a hold to prevent re-upgrade
apt-mark hold <package>
echo "$(date +%Y-%m-%d) | <package> | <version> | Rollback: <reason>" >> /var/log/package_holds.log

# 5. Restart affected services
systemctl restart <service>

# 6. Verify service health
curl -s -o /dev/null -w "%{http_code}" http://localhost/
```

### Using Project Scripts

```bash
# Identify the bad update
./20-identify_bad_update.sh "2025-01-20 03:20"

# Rollback the package
./21-rollback_package.sh <package> <previous_version>

# Prevent re-upgrade
./22-hold_package.sh <package> "Reason for hold"
```

### If Rollback Fails

1. Check if the old version is available: `apt-cache policy <package>`
2. Try installing from cache: `ls /var/cache/apt/archives/<package>*`
3. If version unavailable, download from snapshot.debian.org or snapshot.ubuntu.com
4. As a last resort, restore from system backup

---

## 5. Communication Plan

### Notification Matrix

| Event | Who to Notify | When | Method |
|-------|--------------|------|--------|
| Incident declared (SEV-1) | CISO, CTO, all on-call | Immediately | Phone call + Slack |
| Incident declared (SEV-2) | Team lead, backup engineer | Within 15 min | Slack + email |
| Incident declared (SEV-3) | Team lead | Within 1 hour | Slack |
| Rollback initiated | Application owner | Before starting | Slack |
| Service restored | All stakeholders | Immediately after | Email + Slack |
| Post-incident report | CISO, CAB | Within 48 hours | Email + document |

### Status Update Frequency

| Severity | Update Frequency |
|----------|-----------------|
| SEV-1 | Every 15 minutes until resolved |
| SEV-2 | Every 30 minutes until resolved |
| SEV-3 | Every 2 hours until resolved |

### Communication Templates

**Initial Notification:**

> **[SEV-X] Patch-Related Incident — [Service Name]**
>
> **Time detected:** YYYY-MM-DD HH:MM UTC
> **Impact:** [Description of user impact]
> **Cause:** Suspected package update: [package name]
> **Status:** Investigating / Rolling back / Resolved
> **ETA:** [Estimated resolution time]
> **On-call:** [Engineer name]

**Resolution Notification:**

> **[RESOLVED] Patch-Related Incident — [Service Name]**
>
> **Duration:** X hours Y minutes
> **Root cause:** [Package] update from [old] to [new] caused [symptom]
> **Resolution:** Rolled back to [version], hold applied
> **Follow-up:** Post-incident review scheduled for [date]

---

## 6. Post-Incident Review

### Timeline (Within 48 Hours of Resolution)

1. On-call engineer completes incident report
2. Team lead reviews and schedules PIR meeting
3. PIR meeting held with all involved parties
4. Action items assigned and tracked

### Lessons Learned Template

```
POST-INCIDENT REVIEW
====================

Incident ID: INC-YYYY-NNN
Date: YYYY-MM-DD
Duration: X hours Y minutes
Severity: SEV-X
Participants: [names]

TIMELINE:
---------
HH:MM - [Event]
HH:MM - [Event]
HH:MM - [Event]

ROOT CAUSE:
-----------
[Package name] was updated from [version] to [version] by
[automatic/manual] update at [time]. The new version introduced
[specific change] which caused [specific failure].

IMPACT:
-------
- Users affected: [number/percentage]
- Revenue impact: [estimated]
- Duration of impact: [time]

WHAT WENT WELL:
---------------
1. [Item]
2. [Item]

WHAT WENT WRONG:
----------------
1. [Item]
2. [Item]

ACTION ITEMS:
-------------
| # | Action | Owner | Due Date | Status |
|---|--------|-------|----------|--------|
| 1 | [Action] | [Name] | [Date] | Open |
| 2 | [Action] | [Name] | [Date] | Open |

PREVENTION:
-----------
- Should this package be added to the blacklist? [Yes/No]
- Should the monitoring be enhanced? [Details]
- Should the rollback procedure be updated? [Details]
```

### Review Outcomes

After each PIR, the following must be updated if necessary:

- Package blacklist (`/etc/apt/apt.conf.d/50unattended-upgrades`)
- Monitoring alerts and thresholds
- This incident response procedure
- On-call training materials

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-20 | Security Engineering | Initial procedure creation |
