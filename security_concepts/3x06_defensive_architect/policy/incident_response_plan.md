# Incident Response Plan — Nexus Financial

**Document Reference:** NX-SEC-IRP-001
**Version:** 1.0
**Author:** Interim CISO
**Scope:** All Nexus Financial systems and data
**Distribution:** CTO (Dave), Lead Developer (Sarah), CISO

---

## Purpose

This plan provides a step-by-step playbook for responding to a confirmed or suspected security incident. It is written for Sarah and Dave to execute without the CISO present. Follow the steps in order. Do not improvise. Do not attempt to investigate while the attacker may still be active.

The most important rule: **Contain first, investigate second.**

---

## Incident Classification

| Severity | Definition | Response Time | Example |
|----------|-----------|---------------|---------|
| P0 — Critical | Active breach, data exfiltration in progress, ransomware | Immediate (< 15 min) | Database actively being dumped, ransomware spreading |
| P1 — High | Confirmed unauthorized access, credentials compromised | < 1 hour | SSH key used from unknown IP, admin account logged in from foreign country |
| P2 — Medium | Suspected compromise, anomalous behavior detected | < 4 hours | Unusual query volume, repeated failed auth attempts |
| P3 — Low | Policy violation, no confirmed breach | Next business day | Employee accessing unauthorized files |

---

## Playbook: Compromised Database Scenario

**Trigger:** One or more of the following:
- Unauthorized IP address authenticated to PostgreSQL
- Anomalous query volume (bulk SELECT on customer tables)
- Database user account behaving differently from baseline
- SIEM alert on `pg_audit` log entries from unexpected source
- Customer report of data breach
- Ransomware note found on systems

---

### Phase 1 — Identification

**Objective:** Confirm that an incident is occurring and gather initial evidence.

**Who:** Sarah (Lead Developer) or Dave (CTO) — first person aware of the alert.

**Steps:**

1. **Do not touch the production system yet.** First, gather information passively.

2. Check the PostgreSQL audit log for recent connections:
   ```bash
   sudo grep "CONNECT\|ERROR" /var/log/postgresql/postgresql-*.log | tail -100
   ```

3. Check active database connections:
   ```sql
   SELECT pid, usename, application_name, client_addr, state, query_start
   FROM pg_stat_activity
   WHERE state != 'idle';
   ```

4. Check authentication log for SSH anomalies:
   ```bash
   sudo grep "Accepted\|Failed" /var/log/auth.log | tail -50
   ```

5. Check for unusual network connections:
   ```bash
   sudo ss -tunap | grep 5432
   ```

6. **Document everything:** Screenshot or copy all outputs. Note the exact time of discovery. This is your evidence chain.

7. **Classify the incident** using the table above. If P0 or P1: immediately call the CISO at [CISO emergency number] and send a message to `#incident-response` Slack channel.

8. **Do not notify customers, press, or external parties yet.** All external communications go through Legal.

---

### Phase 2 — Containment

**Objective:** Stop the bleeding. Prevent further data loss or system damage.

**Who:** CISO (remote guidance) + Sarah (technical execution).

**Steps:**

**Immediate network isolation (execute in order):**

1. Block the attacker's IP at the firewall immediately:
   ```bash
   sudo ufw deny from <ATTACKER_IP> to any
   sudo ufw reload
   ```

2. If the attacker is actively connected to the database, terminate their session:
   ```sql
   SELECT pg_terminate_backend(pid)
   FROM pg_stat_activity
   WHERE client_addr = '<ATTACKER_IP>';
   ```

3. If the full extent of compromise is unknown, take the database offline entirely:
   ```bash
   sudo systemctl stop postgresql
   ```
   **Warning:** This stops the application. Confirm with CISO before executing in business hours.

4. Rotate ALL database credentials immediately:
   ```bash
   sudo -u postgres psql -c "ALTER USER app_user PASSWORD '<NEW_RANDOM_32_CHAR_PASSWORD>';"
   ```

5. Revoke all SSH keys if SSH compromise is suspected:
   ```bash
   # On each server:
   echo "" > /home/<user>/.ssh/authorized_keys
   ```
   Individual access is restored only after the incident is contained and each person's key is verified clean.

6. **Preserve a forensic snapshot** before making further changes:
   ```bash
   sudo pg_dumpall > /forensics/db_snapshot_$(date +%Y%m%d_%H%M%S).sql
   sudo cp -a /var/log/ /forensics/logs_$(date +%Y%m%d_%H%M%S)/
   ```

7. Take a memory dump if possible:
   ```bash
   sudo avml /forensics/memory_$(date +%Y%m%d_%H%M%S).lime
   ```

8. **Do not reboot** until forensics are complete. Rebooting destroys in-memory evidence.

---

### Phase 3 — Eradication

**Objective:** Remove the attacker's presence from all systems.

**Who:** CISO-led with Sarah executing.

**Steps:**

1. **Determine the entry point.** Review all logs collected during Identification:
   - Which IP connected first?
   - Which credentials were used?
   - What was the first malicious action?
   - Was any persistence mechanism installed (cron job, SSH key added, new user created)?

2. **Audit all user accounts:**
   ```bash
   awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd
   sudo grep -v "#" /etc/sudoers
   cat /etc/sudoers.d/*
   ```
   Remove any account not in the authorized user list.

3. **Audit all SSH authorized_keys:**
   ```bash
   find /home -name "authorized_keys" -exec cat {} \;
   cat /root/.ssh/authorized_keys
   ```
   Remove any key not in the approved SSH key inventory.

4. **Audit cron jobs for persistence:**
   ```bash
   sudo crontab -l
   for user in $(cut -f1 -d: /etc/passwd); do sudo crontab -u $user -l 2>/dev/null; done
   ls -la /etc/cron* /var/spool/cron/
   ```

5. **Scan for web shells or malicious files:**
   ```bash
   sudo find /var/www /tmp /dev/shm -name "*.php" -o -name "*.sh" | xargs ls -la 2>/dev/null
   sudo rkhunter --check --sk
   ```

6. **Rotate ALL credentials** after eradication is confirmed:
   - All database passwords
   - All SSH keys for all users
   - All API keys
   - All service account credentials

7. **Patch the exploited vulnerability** before bringing systems back online.

---

### Phase 4 — Recovery

**Objective:** Restore normal operations in a verified-clean state.

**Who:** Sarah (execution) + Dave (business continuity decision).

**Steps:**

1. Verify the integrity of the database before restoring service:
   - Compare row counts and checksums against the last known-good backup.
   - Check for unexpected schema changes: new tables, modified stored procedures.
   - Check for new database users: `SELECT * FROM pg_user;`

2. Restore from backup if data integrity is in doubt:
   ```bash
   sudo -u postgres psql < /backup/last_verified_backup.sql
   ```
   **Note:** Verify Kevin's S3 backup script is functional. If the backup is unverified, restore from the most recent verified snapshot before the incident.

3. Bring the database back online with new credentials only:
   ```bash
   sudo systemctl start postgresql
   ```

4. Verify the application connects successfully with rotated credentials.

5. Restore firewall rules to the standard configuration (from `network_defense.sh`).

6. Monitor closely for 48 hours post-recovery:
   - Watch authentication logs every 30 minutes.
   - Watch database query logs for anomalies.
   - Alert on any connection from the blocked attacker IP.

7. **Notify stakeholders** (internal only at first, legal approval required for external):
   - Internal: All-hands message from CEO acknowledging the incident and confirming containment.
   - External: Legal determines notification obligations. Under GDPR: 72-hour notification to supervisory authority if personal data was involved.

---

### Phase 5 — Lessons Learned

**Objective:** Prevent recurrence. Improve the security posture.

**Who:** CISO, Dave, Sarah — meeting within 5 business days of incident closure.

**Required output from the meeting:**

1. **Root cause statement:** One paragraph stating exactly how the attacker got in, what they accessed, and for how long.

2. **Timeline reconstruction:** A chronological list of events from first attacker action to full containment, with timestamps.

3. **Control gap analysis:** For each phase of the attack, identify which control was missing or failed, and what the remediation is.

4. **Action items:** Specific tasks with owners and deadlines to close each gap.

5. **Updated threat model:** The incident reveals real attacker behavior. Update `threat_model.md` with confirmed TTPs.

**Template incident report structure:**
```
Incident ID: INC-[YYYY-MM-DD]-[SEQ]
Severity: P[0-3]
Date Detected: 
Date Contained: 
Total Dwell Time: 
Data Exposed: [Yes/No — what data, how many records]
Entry Point: 
Attacker Actions: 
Root Cause: 
Controls That Failed: 
Controls That Worked: 
Remediations Implemented: 
Open Action Items: 
```

---

## Emergency Contact List

| Role | Name | Contact | Availability |
|------|------|---------|-------------|
| CISO | [Interim CISO] | [emergency phone] | 24/7 during engagement |
| CTO | Dave | [phone/Slack] | 24/7 |
| Lead Developer | Sarah | [phone/Slack] | 24/7 |
| Legal Counsel | [TBD] | [phone] | Business hours + emergency line |
| AWS Support | — | AWS console + support ticket | 24/7 (Business Support tier required) |
| Incident Response Firm | [TBD — recommend retainer] | — | As contracted |

---

## Key Principle

**Do not negotiate with ransomware operators. Do not pay the ransom without legal counsel involvement. Paying the ransom does not guarantee data recovery and may be illegal in certain jurisdictions if the attacker is a sanctioned entity.**
