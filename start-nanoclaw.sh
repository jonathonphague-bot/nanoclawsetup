#!/bin/bash
# start-nanoclaw.sh — Start NanoClaw without systemd
# To stop: kill $(cat nanoclaw.pid)

set -euo pipefail

NANOCLAW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$NANOCLAW_DIR"

# Stop existing instance if running
if [ -f "$NANOCLAW_DIR/nanoclaw.pid" ]; then
  OLD_PID=$(cat "$NANOCLAW_DIR/nanoclaw.pid" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Stopping existing NanoClaw (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    sleep 2
  fi
fi

# Find node — prefer /opt/node22, fall back to system node
NODE_BIN="${NODE_BIN:-}"
for candidate in /opt/node22/bin/node /usr/local/bin/node /usr/bin/node node; do
  if command -v "$candidate" &>/dev/null 2>&1; then
    NODE_BIN="$candidate"
    break
  fi
done

if [ -z "$NODE_BIN" ]; then
  echo "ERROR: node not found. Install Node.js 22+ first."
  exit 1
fi

echo "Starting NanoClaw..."
# Unset any proxy env vars inherited from the shell (e.g. Claude Code's egress proxy)
# so NanoClaw can reach external APIs like Telegram directly.
nohup env -u https_proxy -u http_proxy -u HTTPS_PROXY -u HTTP_PROXY \
  -u GLOBAL_AGENT_HTTP_PROXY -u GLOBAL_AGENT_HTTPS_PROXY \
  -u NODE_TLS_REJECT_UNAUTHORIZED \
  "$NODE_BIN" "$NANOCLAW_DIR/dist/index.js" \
  >> "$NANOCLAW_DIR/logs/nanoclaw.log" \
  2>> "$NANOCLAW_DIR/logs/nanoclaw.error.log" &

echo $! > "$NANOCLAW_DIR/nanoclaw.pid"
echo "NanoClaw started (PID $!)"
echo "Logs: tail -f $NANOCLAW_DIR/logs/nanoclaw.log"
