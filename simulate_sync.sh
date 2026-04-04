#!/bin/bash

# Configuration
PRIMARY_PORT=7331
SECONDARY_PORT=7332
SECONDARY_DIR="/tmp/relix-peer-test"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Relix Local Sync Simulator ===${NC}"

# 1. Setup secondary daemon environment
echo "Setting up secondary peer in $SECONDARY_DIR..."
rm -rf "$SECONDARY_DIR"
mkdir -p "$SECONDARY_DIR"

# 2. Launch secondary daemon
# Assuming ./acorde binary exists in CWD based on ps output
echo "Launching secondary ACORDE daemon on port $SECONDARY_PORT..."
./acorde daemon --name "peer-simulator" --port $SECONDARY_PORT --dir "$SECONDARY_DIR" > "$SECONDARY_DIR/daemon.log" 2>&1 &
PID=$!
echo "Secondary daemon PID: $PID"

# Wait for it to start
sleep 2

# 3. Get Peer IDs
echo "Fetching Peer IDs..."
get_peer_id() {
  local port=$1
  local response=$(curl -s "http://localhost:$port/status")
  echo "DEBUG: Port $port response: $response" >&2
  echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('PeerID', json.load(sys.stdin).get('peer_id', '')))" 2>/dev/null
}

PRIMARY_ID=$(get_peer_id $PRIMARY_PORT)
SECONDARY_ID=$(get_peer_id $SECONDARY_PORT)

echo -e "Primary ID: ${GREEN}$PRIMARY_ID${NC}"
echo -e "Secondary ID: ${GREEN}$SECONDARY_ID${NC}"

if [ -z "$PRIMARY_ID" ] || [ -z "$SECONDARY_ID" ]; then
  echo "Failed to get peer IDs. Is the primary daemon running on $PRIMARY_PORT?"
  kill $PID
  exit 1
fi

# 4. Connect Peers
echo "Connecting peers..."
curl -s -X POST "http://localhost:$PRIMARY_PORT/peers" -d "{\"address\": \"/ip4/127.0.0.1/tcp/$((SECONDARY_PORT+1000))/p2p/$SECONDARY_ID\"}"
curl -s -X POST "http://localhost:$SECONDARY_PORT/peers" -d "{\"address\": \"/ip4/127.0.0.1/tcp/$((PRIMARY_PORT+1000))/p2p/$PRIMARY_ID\"}"

echo -e "${GREEN}✓ Peers Connected${NC}"

# 5. Create a test note on Primary
echo "Creating test note on Primary..."
NOTE_TITLE="Sync Test $(date +%H%M%S)"
curl -s -X POST "http://localhost:$PRIMARY_PORT/entries" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"note\",\"content\":\"eyJ0aXRsZSI6Ii$NOTE_TITLEIiwiYm9keSI6IlRoaXMgbm90ZSBqcHBlZCBhY3Jvc3MgcG9ydHMhIn0=\",\"tags\":[\"remote-test\"]}"

echo "Waiting for sync..."
sleep 3

# 6. Verify on Secondary
echo "Checking Secondary for note..."
RESPONSE=$(curl -s "http://localhost:$SECONDARY_PORT/search?q=Sync%20Test")

if echo "$RESPONSE" | grep -q "$NOTE_TITLE"; then
  echo -e "${GREEN}SUCCESS! Note synced to secondary daemon.${NC}"
  echo "You can query the secondary daemon at http://localhost:$SECONDARY_PORT"
else
  echo -e "${BLUE}Sync pending or failed. Check logs.${NC}"
  echo "$RESPONSE"
fi

# Cleanup
echo "Press ENTER to stop the secondary daemon..."
read
kill $PID
rm -rf "$SECONDARY_DIR"
echo "Done."
