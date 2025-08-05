#!/bin/bash
# Post-tool execution hook for ruv-FANN MCP

TOOL_NAME="$1"
TOOL_RESULT="$2"
SESSION_ID="${SESSION_ID:-$(uuidgen)}"

# Log tool completion
echo "[$(date)] Post-tool: $TOOL_NAME completed" >> /data/memory/tool-log.txt

# Store results in memory
curl -X POST http://localhost:3000/memory \
    -H "Content-Type: application/json" \
    -d "{
        \"key\": \"results/$SESSION_ID/$TOOL_NAME\",
        \"value\": \"$TOOL_RESULT\",
        \"ttl\": 7200
    }" 2>/dev/null

# Tool-specific post-processing
case "$TOOL_NAME" in
    neural_train)
        # Save model weights
        if [ "$SAVE_MODELS" = "true" ]; then
            curl -X POST http://localhost:3000/models/save \
                -H "Content-Type: application/json" \
                -d "{\"session\": \"$SESSION_ID\"}"
        fi
        ;;
    
    swarm_*)
        # Update swarm metrics
        curl -X POST http://localhost:3000/metrics/update
        ;;
    
    daa_workflow_execute)
        # Trigger learning cycle
        curl -X POST http://localhost:3000/daa/learn
        ;;
esac

# Sync with Syncthing if enabled
if [ "$SYNCTHING_API" ]; then
    curl -X POST "$SYNCTHING_API/rest/db/scan?folder=models"
fi

exit 0