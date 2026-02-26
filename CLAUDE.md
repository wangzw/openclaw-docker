# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenClaw Docker is a multi-service Docker deployment for the OpenClaw platform. It runs three containerized services: a central Gateway, a System Node (CLI tools), and a VNC Node (browser automation via Chromium + noVNC).

## Image Hierarchy

```
openclaw-base       Rocky Linux 9 + Node.js 22 + Homebrew + all skill dependencies
    └── openclaw-runtime    Adds the `openclaw` npm package
            ├── openclaw-gateway        Central hub (ports 18789, 1455)
            ├── openclaw-node-system    CLI toolset, runs as root
            └── openclaw-node-vnc       Xvnc + Openbox + Chromium + noVNC + supervisord
```

The base image is intentionally stable and slow-changing; the runtime layer adds only the openclaw CLI so npm updates don't force a full rebuild.

## Build Commands

```bash
./build.sh                # Pull pre-built images; build locally if pull fails
./build.sh --local        # Force local build
./build.sh -v v1.2.3      # Specific version tag
./build.sh -p 1.2.3       # Override openclaw npm package version

# Selective rebuild via compose
docker compose -f docker-compose.build.yml build openclaw-base
docker compose -f docker-compose.build.yml build openclaw-runtime
docker compose -f docker-compose.build.yml build openclaw-gateway openclaw-node-system openclaw-node-vnc
```

Build order matters: base → runtime → service images. This is enforced by `depends_on` in `docker-compose.build.yml`.

## Deploy / Run Commands

`openclaw.sh` is self-contained — all Docker Compose definitions are embedded as heredocs inside the script. It generates `.openclaw-compose.yml` on the fly before each compose operation. No external compose files are needed; just copy the script, create a `.env`, and run.

```bash
./openclaw.sh deploy              # Full deploy: start, pair, configure, restart
./openclaw.sh deploy -v v1.2.3    # Deploy specific version
./openclaw.sh start               # Start all services
./openclaw.sh stop                # Stop all services
./openclaw.sh restart             # Restart all services
./openclaw.sh approve             # Approve pending node pairing requests
./openclaw.sh model               # Configure model settings (interactive)
./openclaw.sh status              # Show health + paired devices
```

Control UI: `http://localhost:18789/#token=${OPENCLAW_GATEWAY_TOKEN}`
noVNC: `http://localhost:6080`

## Key Architecture Details

- **Network**: All services share a Docker bridge network (`openclaw-net`). System and VNC nodes use `socat` to forward the gateway port to localhost, so `openclaw node run` connects via `localhost:18789`.
- **VNC node process management**: supervisord manages xvnc, openbox, noVNC, socat, openclaw-node, and a log-tail aggregator. The `kill-supervisor.py` event listener kills supervisord only on `PROCESS_STATE_FATAL` (not on normal exits, since openclaw-node restarts when gateway restarts).
- **Chromium wrapper**: `/usr/bin/chromium-browser` is a wrapper script that adds `--no-sandbox` and delegates to `chromium-browser.real`.
- **Node pairing flow**: `openclaw.sh deploy` polls `openclaw devices list --json`, auto-approves pending nodes, then configures exec approvals (system-node: allow all; vnc-node: allow only `/usr/bin/chromium-browser`).
- **Gateway config changes cause restarts**: `openclaw config set` may restart the gateway; `gw_config_set()` in `openclaw.sh` handles this with a sleep + health-check wait.
- **First-run onboarding**: Gateway entrypoint checks for `.onboarded` marker file before running `openclaw onboard`.

## Environment Variables

Configured in `.env` (see `.env.example`):

| Variable | Default | Description |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | _(empty)_ | Auth token for gateway API |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway listen port |
| `OPENCLAW_VERSION` | `latest` | Docker image tag |
| `OPENCLAW_SYSTEM_NODE_NAME` | `system-node` | Display name for system node |
| `OPENCLAW_VNC_NODE_NAME` | `vnc-node` | Display name for VNC node |
| `VNC_PW` | `openclaw` | VNC password |
| `VNC_RESOLUTION` | `1280x1024` | VNC display resolution |

## Data Volumes

All runtime state lives under `./data/` (gitignored):

- `data/gateway/data` + `data/gateway/config` — gateway state and config
- `data/node-system/data` — system node state
- `data/node-vnc/data` — VNC node state
- `data/agents` — shared agent workspace (mounted by gateway and system-node)

## CI/CD

- `.github/workflows/docker-images.yml` — Multi-arch (amd64 + arm64) build and push to `ghcr.io/wangzw/openclaw-*`. Detects which images need rebuilding based on changed files.
- `.github/workflows/track-openclaw-release.yml` — Polls npm registry every 6 hours; triggers a runtime rebuild when a new `openclaw` package version is published.

## Shell Script Conventions

All bash scripts use `set -euo pipefail` and colored output via `info()`, `ok()`, `warn()`, `err()` helper functions.
