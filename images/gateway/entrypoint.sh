#!/bin/bash
set -euo pipefail

# ==========================================================
# OpenClaw Gateway Entrypoint
# ==========================================================

ONBOARD_MARKER="${OPENCLAW_STATE_DIR:=/var/lib/openclaw/state}/.onboarded"

if [ ! -f "$ONBOARD_MARKER" ]; then
    echo "[openclaw-gateway] First run detected..."

    # Set workspace before onboard so it's included in the initial config
    WORKSPACE="${OPENCLAW_AGENT_WORKSPACE:-/var/lib/openclaw-agents/workspace}"
    echo "[openclaw-gateway] Setting agents.defaults.workspace=$WORKSPACE"
    openclaw config set agents.defaults.workspace "$WORKSPACE"

    echo "[openclaw-gateway] Allowing Control UI from any origin (Docker LAN)..."
    openclaw config set gateway.controlUi.allowedOrigins '["*"]'

    echo "[openclaw-gateway] Running onboard..."
    # onboard writes config then tries to connect to the gateway websocket,
    # which isn't running yet — ignore that expected connection error
    openclaw onboard \
        --non-interactive \
        --accept-risk \
        --gateway-auth token \
        --gateway-token "${OPENCLAW_GATEWAY_TOKEN:?OPENCLAW_GATEWAY_TOKEN must be set}" \
        || true
    touch "$ONBOARD_MARKER"
    echo "[openclaw-gateway] Onboard complete."
fi

echo "[openclaw-gateway] Starting OpenClaw Gateway..."
echo "[openclaw-gateway] Port: ${OPENCLAW_GATEWAY_PORT:-18789}"

# Run gateway in foreground; forward signals so it shuts down cleanly
openclaw gateway run \
    --port "${OPENCLAW_GATEWAY_PORT:-18789}" \
    --bind lan \
    --verbose \
    --allow-unconfigured &
GATEWAY_PID=$!

trap "kill $GATEWAY_PID 2>/dev/null; wait $GATEWAY_PID" SIGTERM SIGINT
wait $GATEWAY_PID
