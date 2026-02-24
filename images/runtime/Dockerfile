ARG BASE_TAG=latest
FROM ghcr.io/wangzw/openclaw-base:${BASE_TAG}

LABEL maintainer="openclaw"
LABEL description="OpenClaw runtime — base + openclaw CLI"

ARG OPENCLAW_PKG_VERSION=latest
RUN npm install -g openclaw@${OPENCLAW_PKG_VERSION} && \
    rm -rf /root/.npm /tmp/*

ENV OPENCLAW_HOME=/var/lib/openclaw
ENV OPENCLAW_STATE_DIR=/var/lib/openclaw/state
ENV OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
ENV NODE_ENV=production

RUN mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" /etc/openclaw
