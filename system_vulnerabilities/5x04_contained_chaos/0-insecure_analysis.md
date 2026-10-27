# Insecure Dockerfile Analysis — DevStream

## Overview

This document analyzes the vulnerable Dockerfile provided by DevStream and identifies every security issue present. Each finding includes a description of the problem, why it is dangerous, and how an attacker could exploit it.

---

## Finding 1: Unpinned `latest` Tag on Base Image

**Problem:** The Dockerfile uses `FROM ubuntu:latest`. The `latest` tag is mutable — it points to a different image every time Ubuntu publishes an update.

**Why it is dangerous:** Builds are non-deterministic. A build today produces a different image than a build tomorrow. A compromised or buggy upstream push silently changes the foundation of every rebuild. There is no way to audit which exact OS version is running in production.

**Exploitation:** An attacker who compromises the upstream image registry (or performs a supply-chain attack) can inject malicious code into the base layer. Every subsequent build inherits the backdoor. Because there is no pinned digest, the change is invisible.

---

## Finding 2: Bloated Base Image with Excessive Attack Surface

**Problem:** The image is based on full Ubuntu and installs 11 additional packages including `curl`, `wget`, `vim`, `net-tools`, `iputils-ping`, `gcc`, `make`, and `sudo`. Most of these are unnecessary for a Python Flask application.

**Why it is dangerous:** Each additional package increases the attack surface. Network diagnostic tools (`curl`, `wget`, `net-tools`, `ping`) give an attacker reconnaissance and exfiltration capabilities. Compilers (`gcc`, `make`) allow the attacker to compile exploit code inside the container. `vim` provides a text editor for modifying files. The resulting image is 800MB+ instead of the 50-150MB that a slim Python image would require.

**Exploitation:** After compromising the Flask application, an attacker uses `curl` or `wget` to download additional tools or exfiltrate data. They use `gcc` to compile a kernel exploit for container escape. They use `ping` and `net-tools` to map the internal network for lateral movement.

---

## Finding 3: Container Runs as Root

**Problem:** There is no `USER` directive in the Dockerfile. The application runs as `root` (UID 0) inside the container.

**Why it is dangerous:** If an attacker exploits a vulnerability in the Flask application, they immediately have root privileges inside the container. Root inside a container has the same UID as root on the host, and is separated only by kernel namespaces. A single kernel vulnerability (e.g., CVE-2019-5736, CVE-2020-15257) allows escape to the host as root.

**Exploitation:** The attacker exploits an RCE vulnerability in the Flask app. Because the process runs as root, they can: read any file in the container (including mounted volumes), install packages, modify system files, and attempt container escape via kernel exploits. If the Docker socket is mounted (as DevStream was doing), the attacker spawns a privileged container and escapes to the host.

---

## Finding 4: Hardcoded Root Password

**Problem:** The Dockerfile contains `RUN echo 'root:devstream123' | chpasswd`, setting the root password to a known value and embedding it permanently in an image layer.

**Why it is dangerous:** Docker image layers are immutable and visible to anyone with access to the image. The password cannot be removed even by deleting it in a later layer — it remains in the layer history. Anyone who pulls this image can extract the root password.

**Exploitation:** An attacker runs `docker history --no-trunc <image>` and reads the root password directly from the layer. If the same password is reused elsewhere (which is common), the attacker gains access to other systems. Inside the container, any user can `su root` with the known password.

---

## Finding 5: Hardcoded Database Credentials in ENV

**Problem:** The Dockerfile sets production database credentials as environment variables:
```
ENV DB_HOST=prod-db.devstream.internal
ENV DB_USER=admin
ENV DB_PASSWORD=Sup3rS3cr3t!Pr0d
```

**Why it is dangerous:** ENV instructions are stored in the image configuration metadata and are visible via `docker inspect`, `docker history`, and inside every running container. They are not secrets — they are plain-text metadata baked into the image. Anyone with access to the image, the registry, or a running container can read them.

**Exploitation:** An attacker who gains access to the container (or the image registry, or a CI/CD system that builds the image) extracts the credentials with `docker inspect` or by reading `/proc/1/environ`. They then connect directly to `prod-db.devstream.internal` as `admin` with full database access, enabling data exfiltration, modification, or destruction.

---

## Finding 6: `sudo` Installed in Container

**Problem:** The `sudo` package is installed in the container. Combined with the root password set in Finding 4, this provides a privilege escalation path even if a non-root user were configured.

**Why it is dangerous:** If a future developer adds a non-root user but forgets to remove `sudo`, any process that compromises the non-root user can escalate to root using `sudo` with the known password or via `sudo` misconfigurations.

**Exploitation:** An attacker who compromises the application process uses `sudo -l` to check available commands, then escalates to root using the hardcoded password or a misconfigured sudoers entry.

---

## Finding 7: No HEALTHCHECK Instruction

**Problem:** The Dockerfile does not include a `HEALTHCHECK` instruction. Docker has no way to determine if the application inside the container is actually functioning.

**Why it is dangerous:** If the application crashes or hangs, Docker continues to report the container as "running" and routes traffic to it. Orchestrators (Docker Swarm, Kubernetes) cannot make informed rescheduling decisions. An attacker who crashes the application can cause a denial of service that goes undetected.

**Exploitation:** An attacker sends a payload that causes the Flask process to hang (e.g., an infinite loop via a crafted request). The container appears healthy to Docker and the load balancer, but all requests to that instance time out. Without a health check, no automatic recovery occurs.

---

## Finding 8: No Multi-Stage Build

**Problem:** The Dockerfile uses a single stage that includes build tools (`gcc`, `make`, `pip` caches) in the final production image.

**Why it is dangerous:** Build dependencies are only needed during compilation. Including them in the production image unnecessarily increases the image size (800MB+ vs ~150MB) and provides attackers with tools they can use post-compromise. `pip` caches may also contain downloaded source archives with metadata about internal package repositories.

**Exploitation:** After gaining access, the attacker uses `gcc` and `make` to compile privilege escalation exploits or custom tools directly inside the container, without needing to download anything from external sources (which might trigger network alerts).

---

## Finding 9: `COPY . /app` Without `.dockerignore`

**Problem:** The `COPY . /app` instruction copies the entire build context into the image. Without a `.dockerignore` file, this includes `.git/` directories, `.env` files, test credentials, IDE configurations, and any other files in the project directory.

**Why it is dangerous:** The `.git/` directory contains the full repository history, potentially including credentials that were committed and later removed. `.env` files often contain local development secrets. CI/CD configuration files may reveal infrastructure details.

**Exploitation:** An attacker explores `/app/.git/` to find previously committed secrets using `git log -p`. They read `.env` files for additional credentials. They examine CI/CD configurations to understand the deployment pipeline and identify further targets.

---

## Finding 10: pip Install Without `--no-cache-dir`

**Problem:** The `RUN pip3 install -r requirements.txt` command does not use `--no-cache-dir`. pip stores downloaded packages and build artifacts in its cache directory.

**Why it is dangerous:** The pip cache increases image size unnecessarily and may contain source distribution metadata (author emails, repository URLs, internal package index URLs). In a production image, this information has no purpose and only aids attackers.

**Exploitation:** An attacker inspects the pip cache (`/root/.cache/pip/`) to discover internal Python Package Index URLs, package names, and version constraints that reveal information about the application's architecture and dependencies.

---

## Finding 11: No Resource Limits

**Problem:** The Dockerfile does not specify any resource constraints. When run without explicit limits, the container can consume unlimited CPU, memory, and process IDs on the host.

**Why it is dangerous:** A single compromised or malfunctioning container can exhaust host resources, causing a denial of service that affects all other containers and the host operating system itself.

**Exploitation:** An attacker uses a fork bomb or memory allocation loop inside the compromised container to exhaust host resources, crashing all other services. This is especially effective in multi-tenant environments.

---

## Finding 12: No Capability Restrictions

**Problem:** The Dockerfile does not drop any Linux capabilities. By default, Docker containers receive a set of capabilities including `CAP_NET_RAW`, `CAP_SYS_CHROOT`, `CAP_SETUID`, `CAP_SETGID`, and others.

**Why it is dangerous:** These capabilities give the container process abilities it does not need. `CAP_NET_RAW` enables packet sniffing and ARP spoofing. `CAP_SETUID`/`CAP_SETGID` enable privilege manipulation. Combined with running as root (Finding 3), these capabilities provide a broad attack surface for container escape and network attacks.

**Exploitation:** An attacker uses `CAP_NET_RAW` to sniff network traffic between other containers on the same Docker bridge network, intercepting credentials and API tokens. They use `CAP_SYS_CHROOT` in combination with kernel exploits to escape the container namespace.

---

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Unpinned `latest` tag | HIGH |
| 2 | Bloated image with unnecessary tools | HIGH |
| 3 | Running as root | CRITICAL |
| 4 | Hardcoded root password in layer | CRITICAL |
| 5 | Hardcoded database credentials in ENV | CRITICAL |
| 6 | `sudo` installed | HIGH |
| 7 | No HEALTHCHECK | MEDIUM |
| 8 | No multi-stage build | MEDIUM |
| 9 | No `.dockerignore` | HIGH |
| 10 | pip cache in production image | LOW |
| 11 | No resource limits | MEDIUM |
| 12 | No capability restrictions | HIGH |

**Total: 12 distinct security issues identified.**

The three most urgent issues are Findings 3, 4, and 5 — the combination of root execution with hardcoded credentials means that a single application vulnerability gives an attacker full system access plus credentials to the production database.
