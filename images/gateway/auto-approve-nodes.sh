#!/bin/bash
# Auto-approve pending device pairing requests for known nodes.
# Exits once all expected nodes are paired.

POLL_INTERVAL="${AUTO_APPROVE_POLL_INTERVAL:-5}"
TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
TAG="[auto-approve]"

# Only approve devices with these display names
ALLOWED_NAMES="${AUTO_APPROVE_NAMES:-system-node,vnc-node}"

log() { echo "$TAG $*"; }

# Wait for gateway to be ready
until openclaw health > /dev/null 2>&1; do
    sleep 2
done
log "Gateway is ready. Watching for pending devices (expected: ${ALLOWED_NAMES})..."

while true; do
    devices_json=$(openclaw devices list --json 2>/dev/null)

    # Approve pending devices and check if all expected nodes are paired
    result=$(echo "$devices_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    expected = set('${ALLOWED_NAMES}'.split(','))
    # Collect paired display names from the node role devices
    paired = set()
    for entry in data.get('paired', []):
        name = entry.get('displayName', '')
        if name in expected:
            paired.add(name)
    # Print pending requests to approve
    for entry in data.get('pending', []):
        name = entry.get('displayName', '')
        rid = entry.get('requestId', '')
        if rid and name in expected:
            print('APPROVE ' + rid + ' ' + name)
    # Check completion
    if expected <= paired:
        print('ALL_PAIRED')
except Exception:
    pass
" 2>/dev/null)

    all_paired=false
    echo "$result" | while IFS=' ' read -r action arg1 arg2; do
        case "$action" in
            APPROVE)
                log "Approving device: $arg2 ($arg1)"
                if openclaw devices approve "$arg1" --token "$TOKEN" 2>&1; then
                    log "Approved: $arg2"
                else
                    log "Failed to approve: $arg2 ($arg1)"
                fi
                ;;
        esac
    done

    if echo "$result" | grep -q '^ALL_PAIRED$'; then
        log "All expected nodes are paired. Exiting."
        exit 0
    fi

    sleep "$POLL_INTERVAL"
done
