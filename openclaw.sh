#!/bin/bash
set -euo pipefail

# ==========================================================
# OpenClaw CLI
#
# Usage:
#   ./openclaw.sh deploy [ROLE] [-v VERSION]  Deploy and configure services
#   ./openclaw.sh start  [ROLE]               Start services
#   ./openclaw.sh stop   [ROLE]               Stop services
#   ./openclaw.sh restart [ROLE]              Restart services
#   ./openclaw.sh approve                     Approve pending nodes + configure
#   ./openclaw.sh model                       Configure model settings
#   ./openclaw.sh status [ROLE]               Show service health
#
# ROLE: gateway | system-node | vnc-node (omit for all-in-one)
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="$SCRIPT_DIR/.openclaw-compose.yml"
COMPOSE_PROJECT="openclaw"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[openclaw]${NC} $*"; }
ok()    { echo -e "${GREEN}[openclaw]${NC} $*"; }
warn()  { echo -e "${YELLOW}[openclaw]${NC} $*"; }
err()   { echo -e "${RED}[openclaw]${NC} $*" >&2; }

# ==========================================================
# Helpers
# ==========================================================

# Valid roles
is_valid_role() {
    case "$1" in
        gateway|system-node|vnc-node) return 0 ;;
        *) return 1 ;;
    esac
}

# Generate the compose YAML for the given role and write it to $COMPOSE_FILE.
# Uses single-quoted heredoc delimiter so ${VAR:-default} expressions are
# written literally — Docker Compose resolves them at runtime from .env.
generate_compose() {
    local role="${1:-}"
    case "$role" in
        gateway)
            cat > "$COMPOSE_FILE" <<'YAML'
services:
  openclaw-gateway:
    image: ghcr.io/wangzw/openclaw-gateway:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-gateway
    hostname: openclaw-gateway
    init: true
    ports:
      - "${OPENCLAW_GATEWAY_PORT:-18789}:${OPENCLAW_GATEWAY_PORT:-18789}"
      - "${OPENCLAW_OAUTH_PORT:-1455}:${OPENCLAW_OAUTH_PORT:-1455}"
    environment:
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_OAUTH_PORT=${OPENCLAW_OAUTH_PORT:-1455}
      - OPENCLAW_HOME=${OPENCLAW_HOME:-/var/lib/openclaw}
      - OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR:-/var/lib/openclaw/state}
      - OPENCLAW_CONFIG_PATH=${OPENCLAW_CONFIG_PATH:-/etc/openclaw/config.json}
      - NODE_ENV=${NODE_ENV:-production}
    volumes:
      - ./data/gateway/data:/var/lib/openclaw
      - ./data/gateway/config:/etc/openclaw
      - ./data/agents:/var/lib/openclaw-agents
    restart: unless-stopped
YAML
            ;;
        system-node)
            cat > "$COMPOSE_FILE" <<'YAML'
services:
  openclaw-node-system:
    image: ghcr.io/wangzw/openclaw-node-system:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-node-system
    hostname: openclaw-node-system
    environment:
      - OPENCLAW_GATEWAY_HOST=${OPENCLAW_GATEWAY_ADDR:?Set OPENCLAW_GATEWAY_ADDR to the gateway IP/hostname}
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_NODE_NAME=${OPENCLAW_SYSTEM_NODE_NAME:-system-node}
      - OPENCLAW_HOME=/var/lib/openclaw
      - OPENCLAW_STATE_DIR=/var/lib/openclaw/state
      - OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
      - NODE_ENV=${NODE_ENV:-production}
    volumes:
      - ./data/node-system/data:/var/lib/openclaw
      - ./data/agents:/var/lib/openclaw-agents
    restart: unless-stopped
YAML
            ;;
        vnc-node)
            cat > "$COMPOSE_FILE" <<'YAML'
services:
  openclaw-node-vnc:
    image: ghcr.io/wangzw/openclaw-node-vnc:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-node-vnc
    hostname: openclaw-node-vnc
    ports:
      - "${VNC_PORT:-5901}:5901"
      - "${NO_VNC_PORT:-6080}:6080"
    environment:
      - OPENCLAW_GATEWAY_HOST=${OPENCLAW_GATEWAY_ADDR:?Set OPENCLAW_GATEWAY_ADDR to the gateway IP/hostname}
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_NODE_NAME=${OPENCLAW_VNC_NODE_NAME:-vnc-node}
      - OPENCLAW_HOME=/var/lib/openclaw
      - OPENCLAW_STATE_DIR=/var/lib/openclaw/state
      - OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
      - NODE_ENV=${NODE_ENV:-production}
      - VNC_PW=${VNC_PW:-openclaw}
      - VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}
      - DISPLAY=:1
    volumes:
      - ./data/node-vnc/data:/var/lib/openclaw
    shm_size: '2gb'
    restart: unless-stopped
YAML
            ;;
        *)
            cat > "$COMPOSE_FILE" <<'YAML'
services:
  openclaw-gateway:
    image: ghcr.io/wangzw/openclaw-gateway:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-gateway
    hostname: openclaw-gateway
    init: true
    ports:
      - "${OPENCLAW_GATEWAY_PORT:-18789}:${OPENCLAW_GATEWAY_PORT:-18789}"
      - "${OPENCLAW_OAUTH_PORT:-1455}:${OPENCLAW_OAUTH_PORT:-1455}"
    environment:
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_OAUTH_PORT=${OPENCLAW_OAUTH_PORT:-1455}
      - OPENCLAW_HOME=${OPENCLAW_HOME:-/var/lib/openclaw}
      - OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR:-/var/lib/openclaw/state}
      - OPENCLAW_CONFIG_PATH=${OPENCLAW_CONFIG_PATH:-/etc/openclaw/config.json}
      - NODE_ENV=${NODE_ENV:-production}
    volumes:
      - ./data/gateway/data:/var/lib/openclaw
      - ./data/gateway/config:/etc/openclaw
      - ./data/agents:/var/lib/openclaw-agents
    networks:
      - openclaw-net
    restart: unless-stopped

  openclaw-node-system:
    image: ghcr.io/wangzw/openclaw-node-system:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-node-system
    hostname: openclaw-node-system
    environment:
      - OPENCLAW_GATEWAY_HOST=openclaw-gateway
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_NODE_NAME=${OPENCLAW_SYSTEM_NODE_NAME:-system-node}
      - OPENCLAW_HOME=/var/lib/openclaw
      - OPENCLAW_STATE_DIR=/var/lib/openclaw/state
      - OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
      - NODE_ENV=${NODE_ENV:-production}
    volumes:
      - ./data/node-system/data:/var/lib/openclaw
      - ./data/agents:/var/lib/openclaw-agents
    networks:
      - openclaw-net
    depends_on:
      openclaw-gateway:
        condition: service_healthy
    restart: unless-stopped

  openclaw-node-vnc:
    image: ghcr.io/wangzw/openclaw-node-vnc:${OPENCLAW_VERSION:-latest}
    container_name: openclaw-node-vnc
    hostname: openclaw-node-vnc
    ports:
      - "${VNC_PORT:-5901}:5901"
      - "${NO_VNC_PORT:-6080}:6080"
    environment:
      - OPENCLAW_GATEWAY_HOST=openclaw-gateway
      - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
      - OPENCLAW_NODE_NAME=${OPENCLAW_VNC_NODE_NAME:-vnc-node}
      - OPENCLAW_HOME=/var/lib/openclaw
      - OPENCLAW_STATE_DIR=/var/lib/openclaw/state
      - OPENCLAW_CONFIG_PATH=/etc/openclaw/config.json
      - NODE_ENV=${NODE_ENV:-production}
      - VNC_PW=${VNC_PW:-openclaw}
      - VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}
      - DISPLAY=:1
    volumes:
      - ./data/node-vnc/data:/var/lib/openclaw
    networks:
      - openclaw-net
    depends_on:
      openclaw-gateway:
        condition: service_healthy
    shm_size: '2gb'
    restart: unless-stopped

networks:
  openclaw-net:
    driver: bridge
YAML
            ;;
    esac
}

# Return the compose command for the given role.
# Generates the compose file first, then returns the docker compose invocation.
compose_cmd() {
    local role="${1:-}"
    generate_compose "$role"
    echo "docker compose -p $COMPOSE_PROJECT -f $COMPOSE_FILE"
}

# Container names for a given role
containers_for_role() {
    local role="${1:-}"
    case "$role" in
        gateway)     echo "openclaw-gateway" ;;
        system-node) echo "openclaw-node-system" ;;
        vnc-node)    echo "openclaw-node-vnc" ;;
        *)           echo "openclaw-gateway openclaw-node-system openclaw-node-vnc" ;;
    esac
}

wait_for_gateway() {
    info "Waiting for gateway to become healthy..."
    local retries=30
    local i=0
    while [ $i -lt $retries ]; do
        status=$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null || echo "unknown")
        if [ "$status" = "healthy" ]; then
            echo ""
            ok "Gateway is healthy."
            return
        fi
        sleep 3
        i=$((i + 1))
        printf "\r${CYAN}[openclaw]${NC} Waiting for gateway... (%d/%d)" "$i" "$retries"
    done
    echo ""
    err "Gateway did not become healthy after $((retries * 3))s."
    echo ""
    local compose
    compose=$(compose_cmd "${ROLE:-}")
    $compose logs --tail=20 openclaw-gateway 2>/dev/null || docker logs --tail=20 openclaw-gateway 2>/dev/null || true
    exit 1
}

wait_healthy() {
    local role="${1:-}"
    local services
    services=$(containers_for_role "$role")

    info "Waiting for services to become healthy..."

    local retries=30
    for svc in $services; do
        local i=0
        while [ $i -lt $retries ]; do
            status=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "unknown")
            if [ "$status" = "healthy" ]; then
                ok "$svc: healthy"
                break
            fi
            sleep 3
            i=$((i + 1))
            printf "\r${CYAN}[openclaw]${NC} $svc: $status (%d/%d)" "$i" "$retries"
        done
        if [ $i -eq $retries ]; then
            echo ""
            warn "$svc did not become healthy."
        fi
    done
}

# Run a config set command on the gateway.
# The gateway may restart after certain config changes, so we
# tolerate exit code 137 and wait for it to come back.
gw_config_set() {
    docker exec openclaw-gateway openclaw config set "$@" || true
    # Give the gateway time to detect the file change and start restarting
    sleep 3
    wait_for_gateway
}

configure_system_node() {
    local node_name="${OPENCLAW_SYSTEM_NODE_NAME:-system-node}"
    info "Configuring system node ($node_name)..."
    gw_config_set tools.exec.host node
    gw_config_set tools.exec.security full
    gw_config_set tools.exec.node "$node_name"
    info "Setting exec approvals on system node (allow all)..."
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"
    echo '{"version":1,"defaults":{},"agents":{"*":{"allowlist":[{"pattern":"/**"}]}}}' \
        | docker exec -i openclaw-gateway openclaw approvals set --stdin --node "$node_name" --token "$token"
    ok "System node configured."
}

configure_vnc_node() {
    local node_name="${OPENCLAW_VNC_NODE_NAME:-vnc-node}"
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"
    info "Configuring VNC node ($node_name)..."
    gw_config_set gateway.nodes.browser.node "$node_name"
    gw_config_set gateway.nodes.browser.mode manual
    wait_healthy "${ROLE:-}"
    info "Setting exec approvals on VNC node (allow chromium)..."
    local retries=10
    local i=0
    while [ $i -lt $retries ]; do
        if echo '{"version":1,"defaults":{},"agents":{"*":{"allowlist":[{"pattern":"/usr/bin/chromium-browser"}]}}}' \
            | docker exec -i openclaw-gateway openclaw approvals set --stdin --node "$node_name" --token "$token" 2>/dev/null; then
            ok "VNC node configured."
            return
        fi
        sleep 3
        i=$((i + 1))
        info "Waiting for VNC node to reconnect... ($i/$retries)"
    done
    warn "Could not set VNC node approvals — node may not be connected."
}

print_summary() {
    local role="${1:-}"
    local port="${OPENCLAW_GATEWAY_PORT:-18789}"
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  OpenClaw is ready!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""

    if [ -z "$role" ] || [ "$role" = "gateway" ]; then
        echo -e "  Control UI:"
        if [ -n "$token" ]; then
            echo -e "    http://localhost:${port}/#token=${token}"
        else
            echo -e "    http://localhost:${port}/"
        fi
        echo ""
    fi

    local compose_str="docker compose -p $COMPOSE_PROJECT -f $COMPOSE_FILE"
    if [ -z "$role" ]; then
        echo -e "  View logs:"
        echo -e "    $compose_str logs -f"
        echo ""
        echo -e "  Stop all:"
        echo -e "    ./openclaw.sh stop"
    elif [ "$role" = "gateway" ]; then
        echo -e "  View logs:"
        echo -e "    $compose_str logs -f"
        echo ""
        echo -e "  Next steps:"
        echo -e "    Start system-node and vnc-node on their hosts, then run:"
        echo -e "    ./openclaw.sh approve"
    else
        echo -e "  View logs:"
        echo -e "    $compose_str logs -f"
        echo ""
        echo -e "  Next step:"
        echo -e "    Run './openclaw.sh approve' on the gateway host to approve this node."
    fi

    echo ""
}

# ==========================================================
# Subcommands
# ==========================================================

cmd_deploy() {
    local role="${ROLE:-}"
    local version="latest"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version) version="$2"; shift 2 ;;
            *) err "Unknown option for deploy: $1"; exit 1 ;;
        esac
    done
    export OPENCLAW_VERSION="$version"

    echo ""
    echo -e "${BOLD}OpenClaw — Deploy${NC}"
    if [ -n "$role" ]; then
        echo -e "${BOLD}  Role: ${role}${NC}"
    fi
    echo ""

    local compose
    compose=$(compose_cmd "$role")

    case "$role" in
        gateway)
            info "Starting gateway (version: $version)..."
            $compose up -d --remove-orphans
            ok "Gateway started."
            echo ""

            wait_for_gateway
            echo ""

            info "Pairing gateway-local CLI..."
            docker exec openclaw-gateway openclaw devices list --json >/dev/null 2>&1 || true
            sleep 2
            cmd_approve
            echo ""

            print_summary "gateway"
            ;;

        system-node)
            if [ -z "${OPENCLAW_GATEWAY_ADDR:-}" ]; then
                err "OPENCLAW_GATEWAY_ADDR is not set."
                err "Set it to the gateway host's IP/hostname, e.g.:"
                err "  export OPENCLAW_GATEWAY_ADDR=192.168.1.10"
                exit 1
            fi
            info "Starting system node (version: $version)..."
            info "Gateway address: ${OPENCLAW_GATEWAY_ADDR}"
            $compose up -d --remove-orphans
            ok "System node started."
            echo ""

            wait_healthy "system-node"
            echo ""

            print_summary "system-node"
            ;;

        vnc-node)
            if [ -z "${OPENCLAW_GATEWAY_ADDR:-}" ]; then
                err "OPENCLAW_GATEWAY_ADDR is not set."
                err "Set it to the gateway host's IP/hostname, e.g.:"
                err "  export OPENCLAW_GATEWAY_ADDR=192.168.1.10"
                exit 1
            fi
            info "Starting VNC node (version: $version)..."
            info "Gateway address: ${OPENCLAW_GATEWAY_ADDR}"
            $compose up -d --remove-orphans
            ok "VNC node started."
            echo ""

            wait_healthy "vnc-node"
            echo ""

            print_summary "vnc-node"
            ;;

        *)
            # All-in-one (original behavior)
            info "Starting services (version: $version)..."
            $compose up -d --remove-orphans
            ok "Services started."
            echo ""

            wait_for_gateway
            echo ""

            # The gateway-local CLI needs pairing before it can run
            # commands like "approvals set". Trigger a connection attempt
            # so it shows up as pending, then approve it.
            info "Pairing gateway-local CLI..."
            docker exec openclaw-gateway openclaw devices list --json >/dev/null 2>&1 || true
            sleep 2
            cmd_approve
            echo ""

            # Poll and approve node pairing requests until both expected
            # nodes are paired (or timeout after ~90s).
            local system_node="${OPENCLAW_SYSTEM_NODE_NAME:-system-node}"
            local vnc_node="${OPENCLAW_VNC_NODE_NAME:-vnc-node}"
            local token="${OPENCLAW_GATEWAY_TOKEN:-}"
            info "Waiting for nodes to pair ($system_node, $vnc_node)..."
            local approve_timeout=30  # iterations × 3s sleep ≈ 90s
            local approve_i=0
            while [ $approve_i -lt $approve_timeout ]; do
                # Single docker exec: approve pending devices and report paired status
                local result
                result=$(docker exec openclaw-gateway openclaw devices list --json 2>/dev/null \
                    | python3 -c "
import sys, json
data = json.load(sys.stdin)
expected = {'${system_node}', '${vnc_node}'}
# Collect request IDs to approve
for e in data.get('pending', []):
    name = e.get('displayName') or e.get('clientId', '')
    rid = e.get('requestId', '')
    if rid:
        print('APPROVE ' + rid + ' ' + name)
# Check which expected nodes are paired
paired = {e.get('displayName', '') for e in data.get('paired', [])}
if expected <= paired:
    print('ALL_PAIRED')
else:
    missing = expected - paired
    print('MISSING ' + ','.join(sorted(missing)))
" 2>/dev/null || true)

                # Process approvals
                while IFS=' ' read -r action arg1 arg2; do
                    if [ "$action" = "APPROVE" ]; then
                        info "Approving: $arg2 ($arg1)"
                        docker exec openclaw-gateway openclaw devices approve "$arg1" --token "$token" >/dev/null 2>&1 || true
                    fi
                done <<< "$result"

                if echo "$result" | grep -q '^ALL_PAIRED$'; then
                    echo ""
                    ok "Both nodes paired."
                    break
                fi

                sleep 3
                approve_i=$((approve_i + 1))
                local missing
                missing=$(echo "$result" | grep '^MISSING ' | head -1 | cut -d' ' -f2-)
                printf "\r${CYAN}[openclaw]${NC} Waiting for node pairing [missing: %s] (%d/%d)" "${missing:-?}" "$approve_i" "$approve_timeout"
            done
            if [ $approve_i -eq $approve_timeout ]; then
                echo ""
                warn "Node pairing timed out after ~90s. Some nodes may not be paired yet."
                warn "Run './openclaw.sh approve' manually once they appear."
            fi
            echo ""

            wait_healthy
            echo ""

            configure_system_node
            echo ""
            configure_vnc_node
            echo ""

            info "Restarting all services to apply configuration..."
            $compose restart
            echo ""
            wait_for_gateway
            wait_healthy

            print_summary
            ;;
    esac
}

cmd_start() {
    local role="${ROLE:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Start${NC}"
    echo ""

    local compose
    compose=$(compose_cmd "$role")

    if [ -n "$role" ]; then
        info "Starting ${role}..."
    else
        info "Starting all services..."
    fi

    $compose up -d
    echo ""

    if [ -z "$role" ] || [ "$role" = "gateway" ]; then
        wait_for_gateway
    fi
    wait_healthy "$role"

    if [ -n "$role" ]; then
        ok "${role} started."
    else
        ok "All services started."
    fi
    print_summary "$role"
}

cmd_stop() {
    local role="${ROLE:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Stop${NC}"
    echo ""

    local compose
    compose=$(compose_cmd "$role")

    if [ -n "$role" ]; then
        info "Stopping ${role}..."
    else
        info "Stopping all services..."
    fi

    $compose down --remove-orphans

    if [ -n "$role" ]; then
        ok "${role} stopped."
    else
        ok "All services stopped."
    fi
}

cmd_restart() {
    local role="${ROLE:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Restart${NC}"
    echo ""

    local compose
    compose=$(compose_cmd "$role")

    if [ -n "$role" ]; then
        info "Restarting ${role}..."
    else
        info "Restarting all services..."
    fi

    $compose restart
    echo ""

    if [ -z "$role" ] || [ "$role" = "gateway" ]; then
        wait_for_gateway
    fi
    wait_healthy "$role"

    if [ -n "$role" ]; then
        ok "${role} restarted."
    else
        ok "All services restarted."
    fi
}

cmd_approve() {
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Approve Pending Devices${NC}"
    echo ""

    local approved=0
    local ids
    ids=$(docker exec openclaw-gateway openclaw devices list --json 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for entry in data.get('pending', []):
    rid = entry.get('requestId', '')
    name = entry.get('displayName') or entry.get('clientId', '?')
    if rid:
        print(rid + ' ' + name)
" 2>/dev/null || true)

    if [ -z "$ids" ]; then
        info "No pending pairing requests."
    else
        while IFS=' ' read -r request_id name; do
            info "Approving: $name ($request_id)..."
            if docker exec openclaw-gateway openclaw devices approve "$request_id" --token "$token" >/dev/null 2>&1; then
                ok "Approved: $name"
                approved=$((approved + 1))
            else
                warn "Failed to approve: $name"
            fi
        done <<< "$ids"

        echo ""
        ok "Approved $approved device(s)."
    fi

    # Detect paired nodes and configure them
    echo ""
    info "Checking paired nodes for configuration..."
    local paired_nodes
    paired_nodes=$(docker exec openclaw-gateway openclaw devices list --json 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for e in data.get('paired', []):
    name = e.get('displayName') or e.get('clientId', '')
    if name:
        print(name)
" 2>/dev/null || true)

    local system_node="${OPENCLAW_SYSTEM_NODE_NAME:-system-node}"
    local vnc_node="${OPENCLAW_VNC_NODE_NAME:-vnc-node}"
    local configured=false

    if echo "$paired_nodes" | grep -qx "$system_node"; then
        echo ""
        configure_system_node
        configured=true
    fi

    if echo "$paired_nodes" | grep -qx "$vnc_node"; then
        echo ""
        configure_vnc_node
        configured=true
    fi

    if [ "$configured" = true ]; then
        echo ""
        info "Restarting gateway to apply configuration..."
        docker restart openclaw-gateway >/dev/null 2>&1
        wait_for_gateway
    fi

    echo ""
    ok "Done."
}

cmd_status() {
    local role="${ROLE:-}"
    local port="${OPENCLAW_GATEWAY_PORT:-18789}"
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Status${NC}"
    echo ""

    local services
    services=$(containers_for_role "$role")

    for svc in $services; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "not running")
        case "$status" in
            healthy)     ok    "$svc: $status" ;;
            unhealthy)   err   "$svc: $status" ;;
            *)           warn  "$svc: $status" ;;
        esac
    done

    # Show paired devices if gateway is local
    if [ -z "$role" ] || [ "$role" = "gateway" ]; then
        echo ""
        info "Paired devices:"
        docker exec openclaw-gateway openclaw devices list --json 2>/dev/null \
            | python3 -c "
import sys, json
data = json.load(sys.stdin)
for e in data.get('paired', []):
    name = e.get('displayName') or e.get('clientId', '?')
    print(f\"  {name:25s} mode={e.get('clientMode', '?'):10s} role={e.get('role', '?')}\")
pending = data.get('pending', [])
if pending:
    print(f\"  ({len(pending)} pending request(s))\")
" 2>/dev/null || warn "Could not list devices."

        echo ""
        echo -e "  Control UI:"
        if [ -n "$token" ]; then
            echo -e "    http://localhost:${port}/#token=${token}"
        else
            echo -e "    http://localhost:${port}/"
        fi
    fi

    echo ""
}

cmd_model() {
    docker exec -it openclaw-gateway openclaw configure --section model
}

cmd_help() {
    echo "Usage: $0 <command> [ROLE] [options]"
    echo ""
    echo "Commands:"
    echo "  deploy [ROLE] [-v VERSION]  Deploy and configure services (default version: latest)"
    echo "  start  [ROLE]              Start services"
    echo "  stop   [ROLE]              Stop services"
    echo "  restart [ROLE]             Restart services"
    echo "  approve                    Approve pending nodes + configure"
    echo "  model                      Configure model settings"
    echo "  status [ROLE]              Show service health and paired devices"
    echo "  help                       Show this help"
    echo ""
    echo "Roles (optional):"
    echo "  gateway       Gateway only"
    echo "  system-node   System node only"
    echo "  vnc-node      VNC node only"
    echo ""
    echo "Omit ROLE for all-in-one single-host deployment."
    echo ""
    echo "Distributed deployment:"
    echo "  # Gateway host:"
    echo "  ./openclaw.sh deploy gateway"
    echo ""
    echo "  # System-node host (set OPENCLAW_GATEWAY_ADDR first):"
    echo "  export OPENCLAW_GATEWAY_ADDR=<gateway-ip>"
    echo "  ./openclaw.sh deploy system-node"
    echo ""
    echo "  # VNC-node host (set OPENCLAW_GATEWAY_ADDR first):"
    echo "  export OPENCLAW_GATEWAY_ADDR=<gateway-ip>"
    echo "  ./openclaw.sh deploy vnc-node"
    echo ""
    echo "  # Gateway host (after nodes are running):"
    echo "  ./openclaw.sh approve"
    echo ""
}

# ==========================================================
# Main — dispatch subcommand
# ==========================================================

COMMAND="${1:-help}"
shift || true

# Parse optional ROLE argument (first positional arg after command)
ROLE=""
if [[ $# -gt 0 ]] && is_valid_role "${1:-}"; then
    ROLE="$1"
    shift
fi

case "$COMMAND" in
    deploy)  cmd_deploy "$@" ;;
    start)   cmd_start "$@" ;;
    stop)    cmd_stop "$@" ;;
    restart) cmd_restart "$@" ;;
    approve) cmd_approve "$@" ;;
    model)   cmd_model "$@" ;;
    status)  cmd_status "$@" ;;
    help|-h|--help) cmd_help ;;
    *) err "Unknown command: $COMMAND"; echo ""; cmd_help; exit 1 ;;
esac
