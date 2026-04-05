#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Starting Relix Ecosystem ===${NC}"

# 1. Build and Start Acorde Daemon
echo "1. Initializing ACORDE backend..."
if [ -d ../Acorde ]; then
  cd ../Acorde
  if go build -o ../Relix/acorde ./cmd/acorde; then
    echo -e "${GREEN}✓ ACORDE rebuilt from ../Acorde${NC}"
  else
    echo -e "${YELLOW}⚠ ACORDE source build failed; trying existing ./acorde binary${NC}"
  fi
  cd ../Relix
fi

if [ ! -x ./acorde ]; then
  echo -e "${RED}✗ No usable ./acorde binary found. Fix ../Acorde or place a working binary at ./acorde${NC}"
  exit 1
fi

# Try to kill existing daemon if any
pkill -f "acorde daemon" 2>/dev/null || true

# Start daemon in background
# --api-port 7331 is required for Relix to connect
./acorde daemon --data ./data --port 4001 --api-port 7331 > ./acorde.log 2>&1 &
BACKEND_PID=$!
trap "kill $BACKEND_PID" EXIT

sleep 1
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
  echo -e "${RED}✗ ACORDE daemon exited immediately. Check ./acorde.log${NC}"
  exit 1
fi

echo -e "${GREEN}✓ ACORDE Daemon started (PID: $BACKEND_PID)${NC}"

# 2. Start Relix Flutter App
echo "2. Launching Relix Flutter frontend..."
cd frontend
flutter run -d "${RELIX_FLUTTER_DEVICE:-chrome}"
