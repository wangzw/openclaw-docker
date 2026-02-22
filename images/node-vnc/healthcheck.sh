#!/bin/bash
pgrep -f "Xvnc" > /dev/null 2>&1 && \
pgrep -f "openclaw-node" > /dev/null 2>&1
