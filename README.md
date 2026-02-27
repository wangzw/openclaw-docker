# openclaw-docker

Multi-service Docker deployment for the [OpenClaw](https://openclaw.ai) platform. Runs three containerized services: a central Gateway, a System Node (CLI tools), and a VNC Node (browser automation via Chromium + noVNC).

## Architecture

```
openclaw-base       Rocky Linux 9 + Node.js 22 + Homebrew + all skill dependencies
    └── openclaw-runtime    Adds openclaw CLI, claude-code, and opencode-ai
            ├── openclaw-gateway        Central hub (ports 18789, 1455)
            ├── openclaw-node-system    CLI toolset, runs as root
            └── openclaw-node-vnc       Xvnc + Openbox + Chromium + noVNC + supervisord
```

The base image is intentionally stable and slow-changing. The runtime layer adds only the OpenClaw CLI so npm updates don't force a full base rebuild.

## Prerequisites

- Docker with Compose v2
- `gh` CLI (for pulling images from ghcr.io, if not logged in already)

## Quick Start

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env and set OPENCLAW_GATEWAY_TOKEN to a strong secret token
```

### 2. Pull or build images

```bash
./build.sh              # Pull pre-built images; build locally if pull fails
./build.sh --local      # Force local build
./build.sh -v v1.2.3    # Pull/build a specific version
```

### 3. Deploy

```bash
./openclaw.sh deploy
```

This starts all services, waits for them to be healthy, pairs and configures the nodes automatically, then prints the Control UI URL.

**Control UI:** `http://localhost:18789/#token=<OPENCLAW_GATEWAY_TOKEN>`  
**noVNC (browser desktop):** `http://localhost:6080`

## `openclaw.sh` Commands

`openclaw.sh` is self-contained — all Docker Compose definitions are embedded as heredocs. No external compose files are needed. Just copy the script, create a `.env`, and run.

| Command | Description |
|---|---|
| `./openclaw.sh deploy [-v VERSION]` | Full deploy: start, pair, configure, restart |
| `./openclaw.sh start` | Start all services |
| `./openclaw.sh stop` | Stop all services |
| `./openclaw.sh restart` | Restart all services |
| `./openclaw.sh approve` | Approve pending node pairing requests and configure |
| `./openclaw.sh model` | Interactive model configuration |
| `./openclaw.sh status` | Show container health and paired devices |

### Distributed (multi-host) deployment

Each service can run on a separate machine. Provide a `ROLE` argument and set `OPENCLAW_GATEWAY_ADDR` on node hosts:

```bash
# On the gateway host
./openclaw.sh deploy gateway

# On a system-node host (set OPENCLAW_GATEWAY_ADDR in .env first)
./openclaw.sh deploy system-node

# On a vnc-node host
./openclaw.sh deploy vnc-node
```

## Build Commands

```bash
./build.sh                        # Pull pre-built; fallback to local build
./build.sh --local                # Force local build
./build.sh -v v1.2.3              # Specific version tag
./build.sh -p 1.2.3               # Override openclaw npm package version

# Selective rebuild
docker compose -f docker-compose.build.yml build openclaw-base
docker compose -f docker-compose.build.yml build openclaw-runtime
docker compose -f docker-compose.build.yml build openclaw-gateway openclaw-node-system openclaw-node-vnc
```

Build order matters: `base → runtime → service images`. This is enforced by `depends_on` in `docker-compose.build.yml`.

## Environment Variables

Configured in `.env` (see `.env.example`):

| Variable | Default | Description |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | _(required)_ | Auth token for the gateway API and Control UI |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway listen port |
| `OPENCLAW_OAUTH_PORT` | `1455` | OAuth server port |
| `VNC_PORT` | `5901` | Raw VNC port |
| `NO_VNC_PORT` | `6080` | noVNC web port |
| `VNC_PW` | `openclaw` | VNC password |
| `VNC_RESOLUTION` | `1280x1024` | VNC display resolution |
| `OPENCLAW_GATEWAY_ADDR` | _(none)_ | External gateway IP/hostname (distributed mode only) |
| `OPENCLAW_SYSTEM_NODE_NAME` | `system-node` | Display name for the system node |
| `OPENCLAW_VNC_NODE_NAME` | `vnc-node` | Display name for the VNC node |

## Data Volumes

All runtime state is persisted under `./data/` (gitignored):

| Host Path | Service | Contents |
|---|---|---|
| `data/gateway/data` | gateway | Devices, media, cron jobs, extensions |
| `data/gateway/config` | gateway | `config.json` |
| `data/node-system/data` | system-node | Node identity, exec approvals |
| `data/node-vnc/data` | vnc-node | Node identity, browser screenshots |
| `data/agents` | gateway + system-node | Shared agent workspace |

## Services

### Gateway (`openclaw-gateway`)

Central hub. Provides the Control UI, API, and OAuth server. Manages all connected nodes.

- Port `18789`: Gateway API + Control UI
- Port `1455`: OAuth server
- First-run onboarding runs automatically on container start

### System Node (`openclaw-node-system`)

General-purpose CLI execution node. Runs as root with access to all skill tools installed in the base image. Configured to allow execution of any command.

**Included tools:** `gh`, `jq`, `ripgrep`, `ffmpeg`, `uv`, `himalaya`, `gemini-cli`, `whisper`, `spotify_player`, `1password-cli`, `blucli`, `sonoscli`, `nano-pdf`, `obsidian-cli`, `mcporter`, `clawhub`, and more.

### VNC Node (`openclaw-node-vnc`)

Browser automation node. Provides a full graphical desktop (Xvnc + Openbox) accessible via VNC or a web browser through noVNC. Configured to allow only Chromium execution.

- Port `5901`: Raw VNC
- Port `6080`: noVNC web interface
- Chromium runs with `--no-sandbox` (required for root in containers)
- CJK font support included

## Node Pairing

When nodes start, they register as pending pairing requests with the gateway. The `deploy` command handles pairing automatically. For manual approval:

```bash
./openclaw.sh approve
```

## CI/CD

- **`.github/workflows/docker-images.yml`** — Multi-arch (amd64 + arm64) build and push to `ghcr.io/wangzw/openclaw-*`. Smart incremental builds: only rebuilds images affected by changed files.
- **`.github/workflows/track-openclaw-release.yml`** — Polls the npm registry every 6 hours. Triggers a runtime image rebuild automatically when a new `openclaw` package version is published.

Images are published to:
- `ghcr.io/wangzw/openclaw-base`
- `ghcr.io/wangzw/openclaw-runtime`
- `ghcr.io/wangzw/openclaw-gateway`
- `ghcr.io/wangzw/openclaw-node-system`
- `ghcr.io/wangzw/openclaw-node-vnc`
