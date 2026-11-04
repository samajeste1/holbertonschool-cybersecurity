FROM ubuntu:22.04

LABEL maintainer="Security Engineering Team <security@novatech.example>" \
      org.opencontainers.image.title="NovaTech Hardened Shield" \
      org.opencontainers.image.description="Hardened web and SSH base image for NovaTech deployments" \
      org.opencontainers.image.vendor="NovaTech Solutions" \
      org.opencontainers.image.version="1.0.0" \
      com.novatech.application.user="appuser"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        openssh-server \
        python3 \
        curl \
        ca-certificates \
        iproute2 \
        libpam-pwquality \
        libpam-modules \
        passwd \
        procps \
        findutils && \
    rm -rf /var/lib/apt/lists/*

# Application execution identity. PID 1 stays root because sshd refuses to start otherwise.
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --create-home --shell /bin/bash appuser
USER appuser
USER root

COPY scripts/ /opt/novatech/scripts/
COPY config/ /opt/novatech/config/
RUN chmod 755 /opt/novatech/scripts/init-hardening.sh \
        /opt/novatech/scripts/init-identity.sh \
        /opt/novatech/scripts/init-services.sh \
        /opt/novatech/scripts/entrypoint.sh \
        /opt/novatech/scripts/audit.py && \
    /opt/novatech/scripts/init-hardening.sh && \
    /opt/novatech/scripts/init-identity.sh && \
    ssh-keygen -A && \
    rm -rf /home/appuser/.ssh

COPY config/www/index.html /var/www/html/index.html

EXPOSE 80 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
    CMD curl -fsS http://127.0.0.1/ >/dev/null || exit 1

ENTRYPOINT ["/opt/novatech/scripts/entrypoint.sh"]
