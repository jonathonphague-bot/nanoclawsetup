#!/bin/bash
# oracle-server-setup.sh — Run this on your Oracle free tier server
# via a regular SSH terminal (NOT inside Claude Code)
#
# Usage:
#   chmod +x oracle-server-setup.sh
#   bash oracle-server-setup.sh

set -euo pipefail

NANOCLAW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$NANOCLAW_DIR/logs/nanoclaw.log"

echo "================================================"
echo "  NanoClaw Oracle Server Setup"
echo "  Directory: $NANOCLAW_DIR"
echo "================================================"
echo ""

# 1. Ensure Docker is installed and running
echo "[1/5] Checking Docker..."
if ! command -v docker &>/dev/null; then
  echo "  Docker not found. Installing..."
  sudo apt-get update -qq
  sudo apt-get install -y docker.io
  sudo systemctl enable docker
fi

if ! docker info &>/dev/null; then
  echo "  Starting Docker..."
  sudo systemctl start docker 2>/dev/null || sudo service docker start
fi

# Allow current user to run docker without sudo
if ! groups | grep -q docker; then
  sudo usermod -aG docker "$USER" 2>/dev/null || true
fi

echo "  Docker is running."

# 2. Check .env file
echo "[2/5] Checking .env configuration..."
if [ ! -f "$NANOCLAW_DIR/.env" ]; then
  echo "  ERROR: .env file not found at $NANOCLAW_DIR/.env"
  echo "  Please create it with:"
  echo "    CLAUDE_CODE_OAUTH_TOKEN=<your token>"
  echo "    TELEGRAM_BOT_TOKEN=<your bot token>"
  echo "    TZ=UTC"
  exit 1
fi

if ! grep -q "TELEGRAM_BOT_TOKEN" "$NANOCLAW_DIR/.env"; then
  echo "  ERROR: TELEGRAM_BOT_TOKEN not set in .env"
  exit 1
fi

echo "  .env file looks good."

# 3. Sync env to container data directory
echo "[3/5] Syncing environment to container..."
mkdir -p "$NANOCLAW_DIR/data/env"
cp "$NANOCLAW_DIR/.env" "$NANOCLAW_DIR/data/env/env"
echo "  Done."

# 4. Build the container image if needed
echo "[4/5] Checking container image..."
if ! docker image inspect nanoclaw-agent:latest &>/dev/null; then
  echo "  Building agent container image (this may take a few minutes)..."
  bash "$NANOCLAW_DIR/container/build.sh"
else
  echo "  Container image already built."
fi

# 5. Start NanoClaw
echo "[5/5] Starting NanoClaw..."
bash "$NANOCLAW_DIR/start-nanoclaw.sh"

echo ""
echo "================================================"
echo "  NanoClaw is starting!"
echo ""
echo "  Watch the logs with:"
echo "    tail -f $LOG"
echo ""
echo "  Next step — get your Telegram chat ID:"
echo "  1. Open Telegram and find your bot"
echo "  2. Send it:  /chatid"
echo "  3. It will reply with your chat ID"
echo ""
echo "  Then run the registration command:"
echo "    cd $NANOCLAW_DIR"
echo "    npx tsx setup/index.ts --step register -- \\"
echo "      --jid \"tg:<your-chat-id>\" \\"
echo "      --name \"My Chat\" \\"
echo "      --folder telegram_main \\"
echo "      --trigger \"@Andy\" \\"
echo "      --channel telegram \\"
echo "      --no-trigger-required \\"
echo "      --is-main"
echo "================================================"
