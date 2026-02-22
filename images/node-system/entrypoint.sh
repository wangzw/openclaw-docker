#!/bin/bash
set -euo pipefail

GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-openclaw-gateway}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
MAX_RETRIES=30
RETRY_INTERVAL=5

echo "[openclaw-node-system] Waiting for gateway at ${GATEWAY_HOST}:${GATEWAY_PORT}..."

retries=0
until curl -sf "http://${GATEWAY_HOST}:${GATEWAY_PORT}/" > /dev/null 2>&1; do
    retries=$((retries + 1))
    if [ "$retries" -ge "$MAX_RETRIES" ]; then
        echo "[openclaw-node-system] ERROR: Gateway not reachable after ${MAX_RETRIES} retries. Exiting."
        exit 1
    fi
    echo "[openclaw-node-system] Gateway not ready (attempt ${retries}/${MAX_RETRIES}). Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

echo "[openclaw-node-system] Gateway is reachable. Starting socat forward and node..."

# Forward localhost:GATEWAY_PORT to the remote gateway so the node
# connects via localhost (bypassing the plaintext security check).
socat TCP-LISTEN:${GATEWAY_PORT},fork,reuseaddr TCP:${GATEWAY_HOST}:${GATEWAY_PORT} &
SOCAT_PID=$!

openclaw node run \
    --host localhost \
    --port "${GATEWAY_PORT}" \
    --display-name "${OPENCLAW_NODE_NAME:-system-node}" &
NODE_PID=$!

cleanup() {
    kill $NODE_PID 2>/dev/null
    kill $SOCAT_PID 2>/dev/null
    wait $NODE_PID 2>/dev/null
    wait $SOCAT_PID 2>/dev/null
}
trap cleanup SIGTERM SIGINT
wait $NODE_PID
