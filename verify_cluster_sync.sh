#!/bin/bash

# Configuration
NODE_A_PORT=7331
NODE_B_PORT=7332
NODE_C_PORT=7333

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Relix Cluster Sync Verification ===${NC}"
echo "Testing sync propagation across nodes..."

# Generate a unique note payload
TIMESTAMP=$(date +%s)
TITLE="Sync Test $TIMESTAMP"
BODY="This note was created on Node A and should sync to B and C."
# Base64 encode content for ACORDE
CONTENT_JSON="{\"title\":\"$TITLE\",\"body\":\"$BODY\",\"created_at\":$TIMESTAMP,\"updated_at\":$TIMESTAMP}"
CONTENT_B64=$(echo -n "$CONTENT_JSON" | base64 -w 0)

# 1. Create on Node A
echo -e "\n1. Creating note on Node A (Port $NODE_A_PORT)..."
RESPONSE=$(curl -s -X POST "http://localhost:$NODE_A_PORT/entries" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"note\",\"content\":\"$CONTENT_B64\",\"tags\":[\"cluster-test\"]}")

if echo "$RESPONSE" | grep -q "\"id\""; then
    ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Created Note ID: $ID${NC}"
else
    echo -e "${RED}✗ Failed to create note. Is Node A running?${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

# Function to poll a node
check_node() {
    local PORT=$1
    local NAME=$2
    local START_TIME=$(date +%s%N)
    
    echo -n "   Waiting for $NAME (Port $PORT)... "
    
    for i in {1..30}; do
        # We search by title because ID lookup might 404 immediately if not synced
        # But here we assume eventual consistency
        RES=$(curl -s "http://localhost:$PORT/entries/$ID")
        
        if echo "$RES" | grep -q "$TITLE"; then
            local END_TIME=$(date +%s%N)
            local DURATION=$(( ($END_TIME - $START_TIME) / 1000000 ))
            echo -e "${GREEN}✓ Synced in ${DURATION}ms${NC}"
            return 0
        fi
        sleep 0.5
    done
    
    echo -e "${RED}✗ Timed out (15s)${NC}"
    return 1
}

# 2. Check Propagation
echo -e "\n2. Verifying Propagation..."

check_node $NODE_B_PORT "Node B"
check_node $NODE_C_PORT "Node C"

echo -e "\n${BLUE}=== Test Complete ===${NC}"
echo "You can check the UI manually too:"
echo "Node A: http://localhost:3000"
echo "Node B: http://localhost:3001"
echo "Node C: http://localhost:3002"
