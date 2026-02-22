#!/bin/bash
curl -sf "http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}/" > /dev/null 2>&1
