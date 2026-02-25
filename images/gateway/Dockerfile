FROM ghcr.io/wangzw/openclaw-runtime:latest

LABEL maintainer="openclaw"
LABEL description="OpenClaw Gateway on Rocky Linux 9"

# ---------- Gateway-specific environment ----------
ENV OPENCLAW_GATEWAY_PORT=18789
ENV OPENCLAW_OAUTH_PORT=1455

# ---------- Entrypoint & scripts ----------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# ---------- Ports ----------
EXPOSE 18789
EXPOSE 1455

# ---------- Volumes ----------
VOLUME ["/var/lib/openclaw", "/etc/openclaw"]

# ---------- Health check ----------
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
