#!/bin/bash
set -euo pipefail

GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-openclaw-gateway}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
VNC_PW="${VNC_PW:-openclaw}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x1024}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"
MAX_RETRIES=30
RETRY_INTERVAL=5

OPENCLAW_HOME="/home/openclaw"

echo "[openclaw-node-vnc] Configuring VNC for user openclaw..."

# Set VNC password
mkdir -p ${OPENCLAW_HOME}/.vnc
echo "$VNC_PW" | vncpasswd -f > ${OPENCLAW_HOME}/.vnc/passwd
chmod 600 ${OPENCLAW_HOME}/.vnc/passwd

# Create xstartup for openbox window manager
cat > ${OPENCLAW_HOME}/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec openbox-session
XSTARTUP
chmod +x ${OPENCLAW_HOME}/.vnc/xstartup

# Configure openbox autostart to launch tint2 taskbar
mkdir -p ${OPENCLAW_HOME}/.config/openbox
cat > ${OPENCLAW_HOME}/.config/openbox/autostart << 'AUTOSTART'
tint2 &
thunar --daemon &
AUTOSTART

# Ensure openclaw user owns its home and data directories
chown -R openclaw:openclaw ${OPENCLAW_HOME}
chown -R openclaw:openclaw /var/lib/openclaw
chown -R openclaw:openclaw /var/log/supervisor

echo "[openclaw-node-vnc] Waiting for gateway at ${GATEWAY_HOST}:${GATEWAY_PORT}..."

retries=0
until curl -sf "http://${GATEWAY_HOST}:${GATEWAY_PORT}/" > /dev/null 2>&1; do
    retries=$((retries + 1))
    if [ "$retries" -ge "$MAX_RETRIES" ]; then
        echo "[openclaw-node-vnc] ERROR: Gateway not reachable after ${MAX_RETRIES} retries. Exiting."
        exit 1
    fi
    echo "[openclaw-node-vnc] Gateway not ready (attempt ${retries}/${MAX_RETRIES}). Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

echo "[openclaw-node-vnc] Gateway reachable. Starting services via supervisord..."

# Export variables for supervisord child processes
export GATEWAY_HOST GATEWAY_PORT VNC_RESOLUTION VNC_COL_DEPTH

exec /usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf
