# Patch Management & Lifecycle Defense

Security remediation and automated patch management for NovaTech Solutions production environment.

## Project Structure

### Phase 1: System Recovery (Tasks 0-4)
- `0-diagnose_apt.sh` — APT/DPKG diagnostic
- `1-unlock_dpkg.sh` — Emergency unlock
- `2-repair_packages.sh` — Fix broken dependencies
- `3-fix_sources.sh` — Fix repository configuration
- `4-restore_apache.sh` — Restore Apache service

### Phase 2: Vulnerability Remediation (Tasks 5-10)
- `5-remove_vsftpd.sh` — Remove backdoored FTP
- `6-security_updates.sh` — Apply security patches
- `7-harden_ssh.sh` — SSH hardening
- `8-harden_mysql.sh` — MySQL hardening
- `9-fix_permissions.sh` — Fix permissions
- `10-verify_remediation.sh` — Verify all fixes

### Phase 3: Patch Automation (Tasks 12-19)
- `12-package_policy.sh` — Package policy analysis
- `13-setup_unattended.sh` — Enable unattended-upgrades
- `14-security_only.sh` — Security-only filter
- `15-blacklist_packages.sh` — Protect critical services
- `16-maintenance_window.sh` — Schedule maintenance window
- `17-reboot_policy.sh` — Kernel update reboot policy
- `18-notification_setup.sh` — Logging and notifications
- `19-dry_run.sh` — Dry-run validation

### Phase 4: Rollback (Tasks 20-24)
- `20-identify_bad_update.sh` — Identify bad package
- `21-rollback_package.sh` — Version rollback
- `22-hold_package.sh` — Prevent re-upgrade
- `23-manage_holds.sh` — Hold management
- `24-backup_config.sh` — Export configuration

### Phase 5: Documentation (Tasks 25-27)
- `25-patch_note.md` — Patch Management Policy
- `26-playbook.md` — Incident Response Procedure
- `27-remediation_report.md` — Final Remediation Report
