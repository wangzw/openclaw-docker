#!/bin/bash
set -euo pipefail

# ==========================================================
# OpenClaw — Build / Pull Images
#
# Usage:
#   ./build.sh                    # Pull images, build locally on failure
#   ./build.sh -v v1.2.3          # Pull a specific version
#   ./build.sh --local            # Force local build, skip pull
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[openclaw]${NC} $*"; }
ok()    { echo -e "${GREEN}[openclaw]${NC} $*"; }
warn()  { echo -e "${YELLOW}[openclaw]${NC} $*"; }
err()   { echo -e "${RED}[openclaw]${NC} $*" >&2; }

LOCAL_BUILD=false
VERSION="latest"
PKG_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local) LOCAL_BUILD=true; shift ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -p|--pkg-version)
            PKG_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--local] [-v|--version VERSION] [-p|--pkg-version VERSION]"
            echo ""
            echo "  -v, --version VER        Image version/tag to use (default: latest)"
            echo "  -p, --pkg-version VER    openclaw npm package version (default: latest)"
            echo "  --local                  Force local build, skip pulling from registry"
            echo "  -h                       Show this help"
            exit 0
            ;;
        *) err "Unknown option: $1"; exit 1 ;;
    esac
done

export OPENCLAW_VERSION="$VERSION"
if [ -n "$PKG_VERSION" ]; then
    export OPENCLAW_PKG_VERSION="$PKG_VERSION"
fi

build_locally() {
    info "Building base image first..."
    docker compose -f docker-compose.build.yml build openclaw-base
    info "Building service images..."
    docker compose -f docker-compose.build.yml build openclaw-gateway openclaw-node-system openclaw-node-vnc
    ok "All images built successfully."
}

if [ "$LOCAL_BUILD" = "true" ]; then
    info "Force building all images locally (version: $VERSION)..."
    build_locally
else
    info "Pulling images (version: $VERSION)..."
    if docker compose -f docker-compose.build.yml pull --ignore-buildable; then
        ok "Images pulled successfully."
    else
        warn "Pull failed, building locally..."
        build_locally
    fi
fi
