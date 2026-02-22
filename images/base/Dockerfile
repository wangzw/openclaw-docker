FROM rockylinux:9

LABEL maintainer="openclaw"
LABEL description="OpenClaw base image — Rocky Linux 9 + Node.js 22 + openclaw"

# ---------- Node.js 22 LTS ----------
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - && \
    dnf install -y nodejs && \
    dnf clean all

# ---------- EPEL + CRB + system utilities + build tools ----------
RUN dnf install -y epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf install -y --allowerasing \
        procps-ng \
        hostname \
        which \
        findutils \
        python3 \
        python3-pip \
        curl \
        wget \
        git \
        net-tools \
        gcc \
        gcc-c++ \
        make \
        cmake \
        tmux \
        lsof \
        socat \
        golang \
    && dnf clean all

# ---------- Homebrew ----------
RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER linuxbrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
USER root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

# ---------- Install openclaw ----------
ARG OPENCLAW_PKG_VERSION=latest
RUN npm install -g openclaw@${OPENCLAW_PKG_VERSION} && \
    rm -rf /root/.npm /tmp/*

# ---------- Common environment ----------
ENV OPENCLAW_HOME=/var/lib/openclaw
ENV OPENCLAW_STATE_DIR=/var/lib/openclaw/state
ENV OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
ENV NODE_ENV=production

RUN mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" /etc/openclaw
