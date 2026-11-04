# Compliance report

NovaTech Solutions — Hardened Shield base image

## Executive Summary

The infrastructure modernization base image is ready for review. It boots a web server and an SSH server, applies the hardening and identity standards from the previous module, and starts without an operator typing commands. An in-image audit reports a passing score when the container is launched with the supplied compose file.

## Scope

In scope:

- Ubuntu container image built by `Dockerfile`
- System hardening, identity policy, and service startup scripts
- Runtime limits in `docker-compose.yml`
- Audit tool `scripts/audit.py`

Out of scope:

- The business web application that will later be copied onto this base
- Host firewall rules outside Docker
- Physical security of the Docker host

## Controls Implemented

1. Kernel parameters persisted under `/etc/sysctl.d/99-hardening.conf`.
2. Temporary filesystems marked `noexec`, `nosuid`, and `nodev`.
3. SUID bits removed from binaries that are not required to boot or authenticate.
4. Password quality, history, aging, and faillock configured through PAM.
5. SSH restricted to public-key authentication, with root login denied and a legal banner.
6. Root account locked.
7. nginx and sshd started and health-checked by `init-services.sh`.
8. Docker runtime drops all capabilities, adds back only the set sshd and nginx need, sets `no-new-privileges`, and limits memory and process count.
9. No passwords, API keys, or private keys are copied into the image.

## Test Results

| Test | Command | Result |
|---|---|---|
| Image build | `docker compose build` | Pass when Docker can reach Ubuntu package mirrors |
| Container start | `docker compose up -d` | Pass, no manual steps |
| Web | `curl -fsS http://127.0.0.1/` | HTTP response from nginx |
| SSH | TCP port 22 accepts connections, password auth refused | Pass |
| Audit | `python3 /opt/novatech/scripts/audit.py` | Pass at or above 80 percent |
| Image size | `docker image inspect` | Target under 500 MB |

Category scores produced by the auditor: kernel hardening, filesystem security, identity security, service security, container security. The overall percentage and pass/fail status are printed at the end of the report.

## Residual Risks

- Process 1 remains root because OpenSSH will not start as a normal user. The root password is locked and the filesystem is read-only, which limits what a crash in the supervisor can change.
- Several sysctl keys are not writable inside an unprivileged container. The values are still stored in the image so a privileged host can apply them. The live container namespace may keep the host default for those keys.
- fail2ban's jail file is installed. The daemon itself is not required for the health check because faillock already locks accounts.
- Port 22 published on the host can collide with the host sshd. Move the host mapping if that happens, and keep the container port at 22.

## Sign-off

| Role | Name | Decision |
|---|---|---|
| Author | Security Engineering Team | Implementation complete |
| Reviewer | Sarah Chen, CISO, NovaTech Solutions | Pending manual QA |
| Date | 2026-11-04 | Submitted for audit |

The image is not approved for production traffic until the CISO manual review recorded on the intranet is finished.
