ARG BASE_TAG=latest
FROM ghcr.io/wangzw/openclaw-base:${BASE_TAG}

LABEL maintainer="openclaw"
LABEL description="OpenClaw runtime — base + openclaw CLI"

ARG OPENCLAW_PKG_VERSION=latest
RUN npm install -g openclaw@${OPENCLAW_PKG_VERSION} \
                   opencode-ai && \
    rm -rf /root/.npm /tmp/*

# ---------- Claude Code (native installer) ----------
RUN curl -fsSL https://claude.ai/install.sh | bash

# ---------- Claude refresh token helper ----------
COPY claude_refresh_token /usr/local/bin/claude_refresh_token

# ---------- Dummy Claude credentials (populated at runtime) ----------
RUN mkdir -p /root/.claude
COPY credentials.json /root/.claude/.credentials.json

ENV OPENCLAW_HOME=/var/lib/openclaw
ENV OPENCLAW_STATE_DIR=/var/lib/openclaw/state
ENV OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
ENV NODE_ENV=production

RUN mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" /etc/openclaw
