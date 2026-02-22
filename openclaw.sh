#!/bin/bash
set -euo pipefail

# ==========================================================
# OpenClaw CLI
#
# Usage:
#   ./openclaw.sh deploy               # Deploy and configure services
#   ./openclaw.sh deploy -v v1.2.3     # Deploy with a specific version
#   ./openclaw.sh start                # Start all services
#   ./openclaw.sh stop                 # Stop all services
#   ./openclaw.sh restart              # Restart all services
#   ./openclaw.sh approve              # Approve all pending pairing requests
#   ./openclaw.sh model                # Configure model settings
#   ./openclaw.sh status               # Show service health
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

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
    docker compose logs --tail=20 openclaw-gateway
    exit 1
}

wait_all_healthy() {
    info "Waiting for all services to become healthy..."

    local services=("openclaw-gateway" "openclaw-node-system" "openclaw-node-vnc")
    local retries=30

    for svc in "${services[@]}"; do
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
    wait_all_healthy
    info "Setting exec approvals on VNC node (allow chromium)..."
    echo '{"version":1,"defaults":{},"agents":{"*":{"allowlist":[{"pattern":"/usr/bin/chromium-browser"}]}}}' \
        | docker exec -i openclaw-gateway openclaw approvals set --stdin --node "$node_name" --token "$token"
    ok "VNC node configured."
}

print_summary() {
    local port="${OPENCLAW_GATEWAY_PORT:-18789}"
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  OpenClaw is ready!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo -e "  Control UI:"
    if [ -n "$token" ]; then
        echo -e "    http://localhost:${port}/#token=${token}"
    else
        echo -e "    http://localhost:${port}/"
    fi
    echo ""
    echo -e "  View logs:"
    echo -e "    docker compose logs -f"
    echo ""
    echo -e "  Stop all:"
    echo -e "    ./openclaw.sh stop"
    echo ""
}

# ==========================================================
# Subcommands
# ==========================================================

cmd_deploy() {
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
    echo ""

    info "Starting services (version: $version)..."
    docker compose up -d --remove-orphans
    ok "Services started."
    echo ""

    wait_for_gateway
    wait_all_healthy
    echo ""

    # The gateway-local CLI needs pairing before it can run
    # commands like "approvals set". Trigger a connection attempt
    # so it shows up as pending, then approve it.
    info "Pairing gateway-local CLI..."
    docker exec openclaw-gateway openclaw devices list --json 2>/dev/null || true
    sleep 2
    cmd_approve
    echo ""

    configure_system_node
    echo ""
    configure_vnc_node
    echo ""

    info "Restarting all services to apply configuration..."
    docker compose restart
    echo ""
    wait_for_gateway
    wait_all_healthy

    print_summary
}

cmd_start() {
    echo ""
    echo -e "${BOLD}OpenClaw — Start${NC}"
    echo ""
    info "Starting all services..."
    docker compose up -d
    echo ""
    wait_for_gateway
    wait_all_healthy
    ok "All services started."
    print_summary
}

cmd_stop() {
    echo ""
    echo -e "${BOLD}OpenClaw — Stop${NC}"
    echo ""
    info "Stopping all services..."
    docker compose down --remove-orphans
    ok "All services stopped."
}

cmd_restart() {
    echo ""
    echo -e "${BOLD}OpenClaw — Restart${NC}"
    echo ""
    info "Restarting all services..."
    docker compose restart
    echo ""
    wait_for_gateway
    wait_all_healthy
    ok "All services restarted."
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
        return
    fi

    while IFS=' ' read -r request_id name; do
        info "Approving: $name ($request_id)..."
        if docker exec openclaw-gateway openclaw devices approve "$request_id" --token "$token" 2>&1; then
            ok "Approved: $name"
            approved=$((approved + 1))
        else
            warn "Failed to approve: $name"
        fi
    done <<< "$ids"

    echo ""
    ok "Approved $approved device(s)."
}

cmd_status() {
    local port="${OPENCLAW_GATEWAY_PORT:-18789}"
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    echo ""
    echo -e "${BOLD}OpenClaw — Status${NC}"
    echo ""

    local services=("openclaw-gateway" "openclaw-node-system" "openclaw-node-vnc")
    for svc in "${services[@]}"; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "not running")
        case "$status" in
            healthy)     ok    "$svc: $status" ;;
            unhealthy)   err   "$svc: $status" ;;
            *)           warn  "$svc: $status" ;;
        esac
    done

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
    echo ""
}

cmd_model() {
    docker exec -it openclaw-gateway openclaw configure --section model
}

cmd_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy [-v VERSION]  Deploy and configure all services (default version: latest)"
    echo "  start                Start all services"
    echo "  stop                 Stop all services"
    echo "  restart              Restart all services"
    echo "  approve              Approve all pending pairing requests"
    echo "  model                Configure model settings"
    echo "  status               Show service health and paired devices"
    echo "  help                 Show this help"
    echo ""
}

# ==========================================================
# Main — dispatch subcommand
# ==========================================================

COMMAND="${1:-help}"
shift || true

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
