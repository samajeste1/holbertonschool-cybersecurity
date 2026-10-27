# Secure Python Development Environment
# Multi-stage build for minimal attack surface

# Stage 1: Builder - install Python dependencies
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir pylint black pytest mypy

# Stage 2: Runtime - minimal secure image
FROM python:3.11-slim

LABEL maintainer="CyberShield Consulting" \
      description="Secure Python development environment for DevStream" \
      version="1.0" \
      org.opencontainers.image.title="secure-python-dev"

# Install curl for healthcheck, then clean up
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 devuser && \
    useradd -m -u 1000 -g devuser -s /bin/bash devuser

# Copy Python packages from builder stage (no build tools in final image)
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

WORKDIR /app

# Copy application files with correct ownership
# No secrets hardcoded — provide at runtime:
#   docker run -e DB_HOST=host -e DB_USER=user -e DB_PASSWORD=pass
COPY --chown=devuser:devuser . /app

# Switch to non-root user
USER devuser

EXPOSE 5000

# Health monitoring
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["python3", "app.py"]
