FROM rockylinux:9

LABEL maintainer="openclaw"
LABEL description="OpenClaw base image — Rocky Linux 9 + Node.js 22 + tools"

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
        unzip \
        golang \
        poppler-utils \
        tesseract \
        file \
    && dnf clean all

# ---------- Homebrew ----------
RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER linuxbrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
USER root
RUN ln -sf /home/linuxbrew/.linuxbrew/bin/python3 /usr/bin/python3
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

# ---------- Skill dependencies (Homebrew) ----------
# Skipped macOS-only: imsg, camsnap, peekaboo
# Skipped broken on Linux ARM64: sag (ebitengine/oto build failure)
ENV HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
USER linuxbrew
RUN brew install \
        gh \
        jq \
        ripgrep \
        ffmpeg \
        uv \
        himalaya \
        gemini-cli \
        openai-whisper \
        spotify_player \
        1password-cli \
    && brew install steipete/tap/gogcli \
    && brew install steipete/tap/gifgrep \
    && brew install steipete/tap/songsee \
    && brew install steipete/tap/spogo \
    && brew install steipete/tap/goplaces \
    && brew install steipete/tap/ordercli \
    && brew install steipete/tap/wacli \
    && brew install openhue/cli/openhue-cli \
    && brew install xdevplatform/tap/xurl \
    && brew cleanup --prune=all
USER root

# ---------- Skill dependencies (Go) ----------
ENV GOPATH=/root/go
ENV PATH="${GOPATH}/bin:${PATH}"
RUN go install github.com/steipete/blucli/cmd/blu@latest && \
    go install github.com/steipete/sonoscli/cmd/sonos@latest && \
    go install github.com/steipete/eightctl/cmd/eightctl@latest && \
    go install github.com/Hyaxia/blogwatcher/cmd/blogwatcher@latest && \
    rm -rf /root/go/pkg /root/go/src

# ---------- Skill dependencies (Python) ----------
ENV PATH="/root/.local/bin:${PATH}"
RUN uv tool install nano-pdf && \
    uv tool install obsidian-cli && \
    ln -sf /root/.local/bin/obsidian /root/.local/bin/obsidian-cli

# ---------- Skill dependencies (Node) ----------
RUN npm install -g mcporter @steipete/oracle @steipete/summarize clawhub && \
    rm -rf /root/.npm /tmp/*
