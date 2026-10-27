# SUID Decision Matrix — NovaTech Bastion Host

## Purpose

This matrix documents the decision for every SUID/SGID binary found during the audit. Each binary is categorized as KEEP, REMOVE SUID, or INVESTIGATE, with justification.

## Decision Criteria

| Factor | Weight | Description |
|--------|--------|-------------|
| Required for operation | High | Does the web server or SSH need this? |
| GTFOBins listed | High | Can this binary be abused for escalation? |
| Standard system binary | Medium | Is this a default Ubuntu binary in /usr/bin? |
| Admin-only usage | Medium | Can this be replaced by sudo? |
| Custom/third-party | Critical | Non-standard binaries are highest risk |

## SUID Binary Decisions

| Binary | Owner | Decision | Justification |
|--------|-------|----------|---------------|
| `/usr/bin/sudo` | root | **KEEP** | Required for administrative access. Only alternative to direct root login. |
| `/usr/bin/passwd` | root | **KEEP** | Required for users to change their own passwords. CIS allows this. |
| `/usr/bin/su` | root | **KEEP** | Required for switching users via sudo workflows. |
| `/usr/bin/mount` | root | **REMOVE SUID** | Regular users do not mount filesystems on a web server. Admins use sudo. |
| `/usr/bin/umount` | root | **REMOVE SUID** | Same as mount. Not needed for non-root users. |
| `/usr/bin/newgrp` | root | **REMOVE SUID** | Group switching is unnecessary on a web server. |
| `/usr/bin/chsh` | root | **REMOVE SUID** | Users should not change their own shell on a production server. |
| `/usr/bin/chfn` | root | **REMOVE SUID** | Changing finger info is irrelevant on a server. |
| `/usr/bin/gpasswd` | root | **REMOVE SUID** | Group password management not needed. Admins use sudo. |
| `/usr/bin/pkexec` | root | **REMOVE SUID** | PolicyKit execution. Not needed on a headless server. GTFOBins listed. |
| `/usr/bin/at` | root | **REMOVE SUID** | Job scheduling. Cron is preferred and auditable. |
| `/usr/bin/fusermount` | root | **REMOVE SUID** | FUSE mounting. Not needed on a web server. |
| `/usr/bin/ping` | root | **KEEP** | Useful for network diagnostics. Low risk (no shell escape). |
| `/usr/lib/openssh/ssh-keysign` | root | **KEEP** | Required for host-based SSH authentication. |
| `/usr/local/bin/backup` | root | **REMOVE SUID** | Custom binary. Highest risk. Unknown functionality. Must be investigated and SUID removed immediately. |

## SGID Binary Decisions

| Binary | Group | Decision | Justification |
|--------|-------|----------|---------------|
| `/usr/bin/wall` | tty | **REMOVE SGID** | Broadcast messaging. Not needed on a web server. |
| `/usr/bin/write` | tty | **REMOVE SGID** | User messaging. Not needed. |
| `/usr/bin/ssh-agent` | _ssh | **KEEP** | Required for SSH key agent functionality. |
| `/usr/bin/crontab` | crontab | **KEEP** | Required for scheduled task management. |
| `/usr/bin/expiry` | shadow | **KEEP** | Password expiry checking. Low risk. |

## Summary

| Decision | Count | Action |
|----------|-------|--------|
| KEEP SUID/SGID | 7 | No change needed |
| REMOVE SUID/SGID | 8 | Run `chmod u-s` or `chmod g-s` |
| INVESTIGATE | 1 | `/usr/local/bin/backup` requires immediate review |

## Risk Reduction

Removing SUID from 8 binaries eliminates 8 potential privilege escalation vectors. The remaining SUID binaries (sudo, passwd, su, ping, ssh-keysign) are all standard, well-audited system utilities required for server operation.
