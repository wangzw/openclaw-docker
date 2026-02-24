FROM ghcr.io/wangzw/openclaw-runtime:latest

LABEL maintainer="openclaw"
LABEL description="OpenClaw VNC Node on Rocky Linux 9 - Xvnc + Chromium + noVNC"

# ---------- X11, VNC, desktop, Chromium, CJK fonts ----------
RUN dnf install -y --allowerasing \
        tigervnc-server \
        xorg-x11-server-Xvfb \
        xorg-x11-utils \
        xorg-x11-fonts-Type1 \
        xorg-x11-fonts-misc \
        xorg-x11-fonts-75dpi \
        xorg-x11-fonts-100dpi \
        dbus-x11 \
        openbox \
        tint2 \
        Thunar \
        xterm \
        chromium \
        google-noto-sans-cjk-ttc-fonts \
        langpacks-zh_CN \
    && fc-cache -fv \
    && dnf clean all

# ---------- Create non-root user ----------
RUN useradd -m -s /bin/bash openclaw

# ---------- Chromium: --no-sandbox required in containers ----------
# Wrap the real binary so all invocations (desktop, CLI, openclaw) get --no-sandbox
RUN mv /usr/bin/chromium-browser /usr/bin/chromium-browser.real && \
    printf '#!/bin/bash\nexec /usr/bin/chromium-browser.real --no-sandbox "$@"\n' \
        > /usr/bin/chromium-browser && \
    chmod +x /usr/bin/chromium-browser

# ---------- noVNC (web-based VNC access) ----------
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify
COPY index.html /opt/noVNC/index.html

# ---------- Supervisord ----------
RUN uv pip install --system --python /usr/bin/python3 supervisor && \
    mkdir -p /etc/supervisor/conf.d /var/log/supervisor

# ---------- VNC-specific environment ----------
ENV OPENCLAW_GATEWAY_HOST=openclaw-gateway
ENV OPENCLAW_GATEWAY_PORT=18789
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NO_VNC_PORT=6080
ENV VNC_RESOLUTION=1280x1024
ENV VNC_COL_DEPTH=24
ENV VNC_PW=openclaw

# ---------- Supervisord config ----------
COPY supervisord.conf /etc/supervisor/supervisord.conf

# ---------- Entrypoint & scripts ----------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY kill-supervisor.py /usr/local/bin/kill-supervisor.py
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/kill-supervisor.py

# ---------- Ports ----------
EXPOSE 5901
EXPOSE 6080

# ---------- Volume ----------
VOLUME ["/var/lib/openclaw"]

# ---------- Health check ----------
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
