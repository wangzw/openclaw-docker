FROM ghcr.io/wangzw/openclaw-base:latest

LABEL maintainer="openclaw"
LABEL description="OpenClaw System Node on Rocky Linux 9 - CLI tools for system.* operations"

# ---------- Rich CLI toolset for system.* ----------
RUN dnf install -y --allowerasing \
        binutils \
        iproute \
        iputils \
        diffutils \
        lsof \
        strace \
        less \
        sudo \
        tar \
        gzip \
        bzip2 \
        xz \
        unzip \
        zip \
        vim-enhanced \
        passwd \
    && dnf clean all

# ---------- Node-specific environment ----------
ENV OPENCLAW_GATEWAY_HOST=openclaw-gateway
ENV OPENCLAW_GATEWAY_PORT=18789

# ---------- Entrypoint & health check ----------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# ---------- Volume ----------
VOLUME ["/var/lib/openclaw"]

# ---------- Health check ----------
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
