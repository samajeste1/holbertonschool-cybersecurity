# Container Security Guidelines — DevStream

**Version:** 1.0
**Author:** CyberShield Consulting
**Date:** 2026-10-27
**Classification:** Internal — All Engineering Staff

---

## 1. Dockerfile Rules

### Required Practices

- **Pin base image versions.** Always use a specific tag or SHA256 digest, never `latest`.
  ```dockerfile
  # Good
  FROM python:3.11-slim
  # Bad
  FROM python:latest
  ```

- **Use multi-stage builds.** Separate build dependencies from the runtime image. Build tools, compilers, and package managers must not exist in the final image.
  ```dockerfile
  FROM python:3.11-slim AS builder
  RUN pip install --no-cache-dir -r requirements.txt

  FROM python:3.11-slim
  COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
  ```

- **Create and use a non-root user.** Every Dockerfile must include a `USER` directive that switches to an unprivileged user before `CMD` or `ENTRYPOINT`.
  ```dockerfile
  RUN groupadd -g 1000 appuser && useradd -m -u 1000 -g appuser appuser
  USER appuser
  ```

- **Add a HEALTHCHECK.** Every production image must define a health check.
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
      CMD curl -f http://localhost:5000/health || exit 1
  ```

- **Use COPY, not ADD.** `ADD` has implicit behaviors (tar extraction, URL fetching) that introduce risk. Use `COPY` for all file operations.

- **Add LABEL metadata.** Include `maintainer`, `version`, and `description` labels for auditability.

- **Use `--no-cache-dir` with pip.** Prevent pip from storing downloaded archives in the image.

- **Run hadolint on every Dockerfile.** CI must include `hadolint Dockerfile` as a required check. Builds must pass with zero errors.

### Prohibited Practices

- **Never hardcode secrets** in any Dockerfile instruction (ENV, ARG, RUN, COPY). This includes passwords, API keys, tokens, and connection strings.
- **Never install unnecessary tools** such as `curl` (unless required for healthcheck), `wget`, `vim`, `net-tools`, `ssh`, `sudo`, `gcc`, or `make` in the final image.
- **Never use `FROM ubuntu` or `FROM debian`** for application containers. Use language-specific slim images.
- **Never set a root password** inside a container.
- **Never run `chmod 777`** or set world-writable permissions on any file.

---

## 2. Base Image Policy

### Approved Base Images

| Image | Use Case | Max Age |
|-------|----------|---------|
| `python:3.11-slim` | Python applications | 30 days |
| `python:3.12-slim` | Python applications | 30 days |
| `node:20-slim` | Node.js applications | 30 days |
| `golang:1.21-alpine` | Go build stage only | 30 days |
| `gcr.io/distroless/python3` | Python production (no shell) | 30 days |

### Update Requirements

- Base images must be updated at least **monthly** or immediately when a CVE with CVSS >= 7.0 is published for the base image.
- All images must be scanned with **Trivy** before being pushed to the container registry.
- Images with critical or high CVEs in the base layer must not be deployed to production.

### Image Scanning

```bash
# Required before every push to registry
trivy image --severity CRITICAL,HIGH <image_name>

# Must return zero critical/high findings for production deployment
```

---

## 3. Secret Management

### Approved Methods (in order of preference)

1. **External secret manager** (HashiCorp Vault, AWS Secrets Manager, GCP Secret Manager)
   - Application fetches secrets at startup via API
   - Secrets never touch the container image or environment

2. **Mounted secret files**
   - Secrets mounted as read-only files at runtime
   - `docker run -v /path/to/secret:/run/secrets/db_password:ro`

3. **Environment variables at runtime**
   - Passed via `docker run -e` or `--env-file`
   - The `.env` file must be in `.gitignore` and `.dockerignore`
   - `docker run -e DB_PASSWORD=value` or `docker run --env-file .env`

4. **Docker Swarm secrets** (if using Swarm)
   - `docker secret create` + service configuration

### Prohibited Methods

- `ENV` directive in Dockerfile with secret values
- `ARG` directive with secret values (visible in build history)
- `COPY` of files containing secrets into the image
- `RUN echo 'password' | chpasswd` or similar

### Secret Rotation

- Database credentials: rotate every 90 days
- API keys: rotate every 90 days or upon team member departure
- SSH keys: rotate every 180 days

---

## 4. Runtime Requirements

### Mandatory for All Production Containers

| Option | Value | Purpose |
|--------|-------|---------|
| `--cap-drop` | `ALL` | Remove all Linux capabilities |
| `--security-opt` | `no-new-privileges:true` | Block privilege escalation via setuid |
| `--read-only` | (flag) | Prevent filesystem modification |
| `--tmpfs` | `/tmp` | Allow temporary file writes only |
| `--memory` | `256m` (adjust per service) | Prevent memory exhaustion |
| `--memory-swap` | same as `--memory` | Disable swap |
| `--cpus` | `0.5` (adjust per service) | Prevent CPU monopolization |
| `--pids-limit` | `50` (adjust per service) | Prevent fork bombs |
| `--user` | `appuser` or non-root UID | Never run as root |

### Prohibited Runtime Configurations

- **Never mount the Docker socket** (`/var/run/docker.sock`) into a container
- **Never use `--privileged`** flag
- **Never use `--net=host`** unless explicitly approved
- **Never use `--pid=host`** or `--ipc=host`
- **Never add capabilities** (`--cap-add`) without documented justification

### Example Run Command

```bash
docker run -d \
    --name myapp \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    --read-only \
    --tmpfs /tmp \
    --memory=256m \
    --memory-swap=256m \
    --cpus=0.5 \
    --pids-limit=50 \
    --user=appuser \
    -p 5000:5000 \
    myapp:v1
```

---

## 5. Audit Requirements

### Pre-Deployment Audit

Every container image must pass the following checks before production deployment:

1. **Hadolint scan** — zero errors on the Dockerfile
2. **Trivy scan** — zero critical or high CVEs
3. **docker-bench-security** — score >= 80%
4. **Manual review** — verify USER, HEALTHCHECK, no secrets, multi-stage build

### Continuous Auditing

- Weekly automated Trivy scans of all running production images
- Monthly docker-bench-security audit of the Docker host configuration
- Quarterly manual review of all Dockerfiles against these guidelines
- Immediate audit upon any container security incident

### Audit Documentation

Each audit must produce a record containing:
- Date and auditor name
- Image name and tag/digest
- Tool versions used
- Findings with severity ratings
- Remediation actions taken (if any)

---

## 6. Exception Process

If a team member needs to deviate from these guidelines (e.g., adding a capability, using a non-approved base image, running as root), they must:

1. **Submit a written request** to the Security team via the `#security-exceptions` channel
2. **Include:**
   - Which guideline is being excepted
   - Technical justification (why the guideline cannot be followed)
   - Risk assessment (what additional risk does this introduce)
   - Compensating controls (what measures will reduce the additional risk)
   - Duration (how long the exception is needed)
3. **Obtain approval** from both the Engineering Lead and the Security Lead
4. **Document the exception** in the team's security exception register
5. **Set a review date** — exceptions expire after 90 days and must be re-approved

### Permanent Exceptions

No permanent exceptions are granted. All exceptions must be reviewed quarterly. If the underlying technical constraint has not been resolved, the exception may be renewed with updated justification.

### Emergency Exceptions

In case of a production incident requiring an immediate deviation, the on-call engineer may bypass this process temporarily. The exception must be documented retroactively within 24 hours and reviewed within 7 days.
