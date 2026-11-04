# Security Audit Result

## Kernel hardening

- [PASS] net.ipv4.ip_forward = 0
- [PASS] reverse path filter enabled
- [PASS] SYN cookies enabled
- [PASS] ICMP redirects disabled
- [PASS] source routing disabled

Score: 5/5

## Filesystem security

- [PASS] /tmp noexec in fstab
- [PASS] /tmp nosuid in fstab
- [PASS] /tmp nodev in fstab
- [PASS] /dev/shm noexec in fstab

Score: 4/4

## Identity security

- [PASS] password minlen 12
- [PASS] faillock deny 5
- [PASS] PermitRootLogin no
- [PASS] PasswordAuthentication no
- [PASS] PASS_MAX_DAYS 90
- [PASS] root account locked

Score: 6/6

## Service security

- [PASS] nginx running
- [PASS] sshd running
- [PASS] port 80 and 22 listening
- [PASS] legal banner present
- [PASS] web health check

Score: 5/5

## Container security

- [PASS] running inside a container
- [PASS] non-root application user appuser
- [PASS] no-new-privileges on pid 1
- [PASS] host keys present

Score: 4/4

## Overall

Passed checks: 24/24

Overall percentage: 100%

Pass/fail status: PASS
