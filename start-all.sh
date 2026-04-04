#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Starting Relix Ecosystem ===${NC}"

# 1. Build and Start Acorde Daemon
echo "1. Initializing ACORDE backend..."
cd ../Acorde
go build -o ../Relix/acorde ./cmd/acorde
cd ../Relix

# Try to kill existing daemon if any
pkill -f "acorde daemon" 2>/dev/null

# Start daemon in background
# --api-port 7331 is required for Relix to connect
./acorde daemon --data ./data --port 4001 --api-port 7331 > ./acorde.log 2>&1 &
BACKEND_PID=$!

echo -e "${GREEN}✓ ACORDE Daemon started (PID: $BACKEND_PID)${NC}"

# 2. Start Relix Web App
echo "2. Launching Relix Frontend..."
npm run dev

# Cleanup on exit
trap "kill $BACKEND_PID" EXIT
