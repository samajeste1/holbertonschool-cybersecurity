# SUID Decision Matrix — NovaTech Bastion Host

## Purpose

This matrix documents the decision for every SUID/SGID binary found during the audit. For each binary, we explain what it does, why it needs SUID, the risk if compromised, and the recommendation.

## Decision Criteria

| Factor | Weight | Description |
|--------|--------|-------------|
| Required for operation | High | Does the web server or SSH need this? |
| GTFOBins listed | High | Can this binary be abused for escalation? |
| Standard system binary | Medium | Is this a default Ubuntu binary in /usr/bin? |
| Admin-only usage | Medium | Can this be replaced by sudo? |
| Custom/third-party | Critical | Non-standard binaries are highest risk |

## SUID Binary Decisions

### /usr/bin/sudo

- **What it does:** Allows permitted users to execute commands as root or another user based on /etc/sudoers policy.
- **Why it needs SUID:** Must elevate from normal user privileges to root in order to execute the requested command. Without SUID, unprivileged users cannot gain root access.
- **Risk if compromised:** Complete system compromise — an attacker gains arbitrary root command execution. However, sudo is heavily audited and logs all commands.
- **Recommendation:** **KEEP** — Essential for all administrative access. Only mechanism for non-root users to perform privileged operations.

### /usr/bin/passwd

- **What it does:** Allows users to change their own password by writing to /etc/shadow, which is only readable/writable by root.
- **Why it needs SUID:** /etc/shadow is owned by root with mode 640. Without SUID, normal users cannot update their own password hash.
- **Risk if compromised:** An attacker could change any user's password, locking out legitimate users or gaining access to other accounts.
- **Recommendation:** **KEEP** — Required for password management. CIS Benchmark explicitly allows this SUID bit.

### /usr/bin/su

- **What it does:** Switches the current user to another user (typically root) after password authentication.
- **Why it needs SUID:** Must access /etc/shadow to verify the target user's password and must create a new session as that user.
- **Risk if compromised:** Could allow an attacker to switch to any user without authentication, including root.
- **Recommendation:** **KEEP** — Required for sudo workflows and emergency access patterns. Access can be restricted via /etc/pam.d/su.

### /usr/bin/ping

- **What it does:** Sends ICMP echo requests to test network connectivity to a remote host.
- **Why it needs SUID:** Requires raw socket access (CAP_NET_RAW) to craft ICMP packets, which is a root-level capability.
- **Risk if compromised:** Limited — ping has no shell escape or file write capability. An attacker could craft arbitrary ICMP packets but cannot escalate privileges.
- **Recommendation:** **KEEP** — Useful for network diagnostics. Low risk with no known privilege escalation vectors.

### /usr/lib/openssh/ssh-keysign

- **What it does:** Signs SSH host-based authentication requests using the host's private SSH key.
- **Why it needs SUID:** Must read /etc/ssh/ssh_host_*_key files which are owned by root and mode 600.
- **Risk if compromised:** An attacker could sign authentication requests as the host, potentially impersonating the server to other systems.
- **Recommendation:** **KEEP** — Required for SSH host-based authentication. Only invoked by sshd, not directly by users.

### /usr/bin/mount

- **What it does:** Mounts filesystems (USB drives, network shares, disk partitions) to directories in the filesystem tree.
- **Why it needs SUID:** Mounting filesystems is a privileged kernel operation requiring root access.
- **Risk if compromised:** An attacker could mount a malicious filesystem containing SUID binaries or overwrite system directories. GTFOBins lists mount as exploitable.
- **Recommendation:** **REMOVE SUID** — Regular users do not mount filesystems on a bastion host. Administrators can use `sudo mount`.

### /usr/bin/umount

- **What it does:** Unmounts previously mounted filesystems.
- **Why it needs SUID:** Unmounting is a privileged kernel operation requiring root.
- **Risk if compromised:** An attacker could unmount critical filesystems (/var/log, /tmp), causing denial of service or disabling security logging.
- **Recommendation:** **REMOVE SUID** — Same rationale as mount. Administrators can use `sudo umount`.

### /usr/bin/newgrp

- **What it does:** Changes the current user's primary group ID to another group they belong to, starting a new shell.
- **Why it needs SUID:** Must access /etc/gshadow to verify group passwords and modify the process's group credentials.
- **Risk if compromised:** An attacker could switch to any group, potentially accessing files restricted to that group. Also spawns a new shell which could be abused.
- **Recommendation:** **REMOVE SUID** — Group switching is unnecessary on a bastion host. No multi-group workflows exist.

### /usr/bin/chsh

- **What it does:** Changes a user's login shell (e.g., from /bin/bash to /bin/zsh).
- **Why it needs SUID:** Must write to /etc/passwd which is owned by root.
- **Risk if compromised:** An attacker could change a user's shell to a malicious binary, achieving code execution on next login.
- **Recommendation:** **REMOVE SUID** — Users should not change their login shell on a production server. Admin can use `sudo chsh` if needed.

### /usr/bin/chfn

- **What it does:** Changes user information in the GECOS field of /etc/passwd (full name, phone, office).
- **Why it needs SUID:** Must write to /etc/passwd which is owned by root.
- **Risk if compromised:** Could modify /etc/passwd entries. While GECOS fields are informational, the write access to /etc/passwd is the real danger.
- **Recommendation:** **REMOVE SUID** — Finger information is irrelevant on a server. No legitimate use case.

### /usr/bin/gpasswd

- **What it does:** Administers /etc/group and /etc/gshadow — adds/removes users from groups, sets group passwords.
- **Why it needs SUID:** Must write to /etc/group and /etc/gshadow which are owned by root.
- **Risk if compromised:** An attacker could add themselves to privileged groups (sudo, adm, shadow), effectively gaining root-equivalent access.
- **Recommendation:** **REMOVE SUID** — Group management should be done exclusively through sudo. No self-service group changes needed.

### /usr/bin/pkexec

- **What it does:** PolicyKit execution agent — allows running programs as another user based on PolicyKit policies, similar to sudo but for desktop environments.
- **Why it needs SUID:** Must elevate privileges to execute commands as another user per PolicyKit authorization.
- **Risk if compromised:** Complete system compromise. CVE-2021-4034 (PwnKit) demonstrated a 12-year-old vulnerability allowing any local user to gain root. Listed on GTFOBins.
- **Recommendation:** **REMOVE SUID** — Not needed on a headless server. High risk due to known CVEs and GTFOBins listing.

### /usr/bin/at

- **What it does:** Schedules one-time commands to execute at a specified time using the atd daemon.
- **Why it needs SUID:** Must access the at spool directory and submit jobs that run as the submitting user.
- **Risk if compromised:** An attacker could schedule persistent backdoor execution. Jobs survive logout and are harder to detect than cron entries.
- **Recommendation:** **REMOVE SUID** — Cron is the preferred and more auditable scheduling mechanism. at is unnecessary.

### /usr/bin/fusermount

- **What it does:** Mounts and unmounts FUSE (Filesystem in Userspace) filesystems like sshfs, ntfs-3g, or AppImage mounts.
- **Why it needs SUID:** FUSE mount/unmount operations require root-level filesystem operations.
- **Risk if compromised:** Could mount attacker-controlled filesystems containing malicious content or SUID binaries.
- **Recommendation:** **REMOVE SUID** — FUSE is not needed on a bastion host. No user-space filesystems should be mounted.

### /usr/local/bin/backup (if present)

- **What it does:** Custom binary — unknown functionality. Likely a backup script or tool installed by an administrator.
- **Why it needs SUID:** Unknown — custom binaries with SUID are the highest risk category.
- **Risk if compromised:** Unknown code with root privileges. Could contain command injection, path traversal, or other vulnerabilities. Maximum risk.
- **Recommendation:** **REMOVE SUID IMMEDIATELY** — Custom SUID binaries must be investigated. Replace with a cron job running as root or a sudo-based wrapper.

## SGID Binary Decisions

### /usr/bin/wall

- **What it does:** Broadcasts a message to all logged-in users' terminals.
- **Why it needs SGID:** Requires tty group access to write to other users' terminal devices.
- **Risk if compromised:** Could spam terminals or be used for social engineering attacks against administrators.
- **Recommendation:** **REMOVE SGID** — Terminal broadcasting is not needed on a bastion host.

### /usr/bin/write

- **What it does:** Sends a message to another logged-in user's terminal.
- **Why it needs SGID:** Requires tty group access to write to another user's terminal device.
- **Risk if compromised:** Similar to wall — social engineering risk.
- **Recommendation:** **REMOVE SGID** — Inter-user messaging not needed on a server.

### /usr/bin/ssh-agent

- **What it does:** Holds SSH private keys in memory for passwordless authentication to remote servers.
- **Why it needs SGID:** Requires _ssh group access for secure communication with SSH processes.
- **Risk if compromised:** Could expose cached SSH private keys, allowing lateral movement to other servers.
- **Recommendation:** **KEEP** — Required for SSH key agent functionality used by administrators.

### /usr/bin/crontab

- **What it does:** Manages per-user cron job schedules stored in /var/spool/cron.
- **Why it needs SGID:** Requires crontab group access to read/write the cron spool directory.
- **Risk if compromised:** An attacker could create persistent scheduled tasks running as any user.
- **Recommendation:** **KEEP** — Required for scheduled task management. Access audited via syslog.

### /usr/bin/expiry

- **What it does:** Checks and enforces password expiration policies against /etc/shadow.
- **Why it needs SGID:** Requires shadow group access to read password aging information.
- **Risk if compromised:** Could read password hashes from /etc/shadow for offline cracking.
- **Recommendation:** **KEEP** — Required for password expiry enforcement. Low direct risk.

## Summary

| Decision | Count | Action |
|----------|-------|--------|
| KEEP SUID/SGID | 8 | No change needed |
| REMOVE SUID/SGID | 9 | Run `chmod u-s` or `chmod g-s` |
| INVESTIGATE | 1 | `/usr/local/bin/backup` requires immediate review |

## Risk Reduction

Removing SUID/SGID from 9 binaries eliminates 9 potential privilege escalation vectors. The remaining binaries (sudo, passwd, su, ping, ssh-keysign, ssh-agent, crontab, expiry) are all standard, well-audited system utilities required for server operation. The most critical removal is pkexec due to CVE-2021-4034 and any custom binaries in /usr/local.
