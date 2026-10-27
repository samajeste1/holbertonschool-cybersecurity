# Secure Python Development Environment — Design Document

## 1. Base Image Selection

**Image:** `python:3.11-slim`

**Rationale:**
- Official Python image maintained by Docker and the Python community
- Debian-slim variant strips documentation, man pages, and non-essential packages
- Size is approximately 120MB compared to 900MB+ for `ubuntu:latest` with manual Python installation
- Pre-configured Python environment eliminates the need for system-level pip installation
- Receives regular security patches from the upstream maintainers

**Rejected alternatives:**
- `python:3.11-alpine`: Smaller (~50MB) but uses musl libc, which causes compatibility issues with certain Python packages that rely on glibc (e.g., pandas, numpy with C extensions)
- `ubuntu:latest`: Unnecessarily large, requires manual Python installation, `latest` tag is non-deterministic
- `python:3.11`: Full Debian image with build tools; 350MB+ larger than `slim` with no runtime benefit

## 2. Included Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.11.x | Runtime interpreter |
| pip | latest | Package management (in builder stage only) |
| venv | built-in | Virtual environment support |
| pylint | latest | Static code analysis and linting |
| black | latest | Code formatting (PEP 8 compliance) |
| pytest | latest | Unit and integration testing |
| mypy | latest | Static type checking |
| curl | system | HEALTHCHECK endpoint verification |

All development tools are installed in the builder stage and only the compiled artifacts are copied to the runtime image. pip caches are excluded from the final image.

## 3. User Configuration

- **Username:** `devuser`
- **UID/GID:** 1000/1000
- **Shell:** `/bin/bash`
- **Home:** `/home/devuser`

The user is created with `groupadd` and `useradd` to ensure deterministic UID/GID assignment. The `USER devuser` directive ensures all subsequent commands (including CMD) run as this unprivileged user. The UID 1000 is chosen to match the default first user on most Linux distributions, which simplifies volume permission handling during development.

## 4. Volume Strategy

- **Code mount:** `./workspace:/app/workspace` — the developer's local code directory is bind-mounted into the container so that edits on the host are immediately visible inside the container
- **Writable tmpfs:** `/tmp` and `/app/logs` are mounted as tmpfs to allow the application to write temporary files and logs without compromising the read-only root filesystem
- **No sensitive mounts:** The Docker socket (`/var/run/docker.sock`) is never mounted. Host `/etc`, `/proc`, and `/sys` are not exposed.

## 5. Security Measures

| Measure | Implementation | Purpose |
|---------|---------------|---------|
| Non-root user | `USER devuser` | Prevent privilege abuse |
| Multi-stage build | `FROM ... AS builder` | Exclude build tools from runtime |
| No hardcoded secrets | ENV removed | Secrets provided at runtime only |
| Read-only filesystem | `--read-only` | Prevent attacker file modification |
| Capability drop | `--cap-drop=ALL` | Minimize kernel-level privileges |
| No new privileges | `--security-opt=no-new-privileges` | Block setuid escalation |
| Resource limits | `--memory=256m --cpus=0.5 --pids-limit=50` | Prevent resource exhaustion |
| Health monitoring | `HEALTHCHECK` instruction | Detect application failures |
| Seccomp | Default profile | Restrict dangerous syscalls |
| Minimal image | `python:3.11-slim` | Reduce attack surface |

## 6. Developer Experience

**Starting the environment:**
```bash
docker-compose run --rm dev bash          # Interactive shell
docker-compose run --rm dev python app.py # Run application
docker-compose run --rm dev pytest tests/ # Run tests
docker-compose run --rm dev pylint src/   # Lint code
docker-compose run --rm dev black .       # Format code
docker-compose run --rm dev mypy src/     # Type check
```

**Workflow:**
1. Developer writes code on their host machine in the `workspace/` directory
2. Code is instantly available inside the container via bind mount
3. All tools run inside the container with consistent versions across the team
4. Security controls are transparent — the developer does not need to configure them manually

**Trade-offs:**
- Read-only filesystem means pip install inside the container requires rebuilding the image. This is intentional: all dependencies should be declared in `requirements.txt` and baked into the image.
- Running as non-root means the container cannot bind to ports below 1024. The application uses port 5000, which is above this threshold.
- Resource limits may need adjustment for heavy workloads (e.g., running a full test suite with coverage analysis). The compose file documents where to change these values.
