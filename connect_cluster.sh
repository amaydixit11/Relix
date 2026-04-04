#!/bin/bash

# Configuration
ACORDE_BIN="/home/amaydixit11/Desktop/dev/vaultd/acorde"
PORTS=(7331 7332 7333)

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Relix Cluster Auto-Connect ===${NC}"

if [ ! -f "$ACORDE_BIN" ]; then
    echo "Error: acorde binary not found at $ACORDE_BIN"
    echo "Please update the script with the correct path."
    exit 1
fi

echo "Detected 3 nodes. Establishing mesh..."

# 1. Generate Invite from Node 1 (Hub)
echo -e "\n1. Generating invite from Node 1 (Port ${PORTS[0]})..."
INVITE_OUTPUT=$(ACORDE_PORT=${PORTS[0]} $ACORDE_BIN invite --share-key 2>&1)

# Extract the acorde:// URI
INVITE_URI=$(echo "$INVITE_OUTPUT" | grep -o 'acorde://[^[:space:]]*')

if [ -z "$INVITE_URI" ]; then
    echo "Failed to generate invite. Output:"
    echo "$INVITE_OUTPUT"
    exit 1
fi

echo "   Invite Token: $INVITE_URI"

# 2. Connect Node 2 to Node 1
echo -e "\n2. Connecting Node 2 (Port ${PORTS[1]}) to Node 1..."
ACORDE_PORT=${PORTS[1]} $ACORDE_BIN pair "$INVITE_URI"

# 3. Connect Node 3 to Node 1
echo -e "\n3. Connecting Node 3 (Port ${PORTS[2]}) to Node 1..."
ACORDE_PORT=${PORTS[2]} $ACORDE_BIN pair "$INVITE_URI"

echo -e "\n${GREEN}✓ Cluster Connected!${NC}"
echo "Topology: Node 2 & 3 are now paired with Node 1."
echo "Changes made in any app should sync to the others."
