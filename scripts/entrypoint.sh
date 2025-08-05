#!/bin/bash
# ruv-FANN Container Entrypoint Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting ruv-FANN Neural Engine...${NC}"

# Function to wait for service
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    
    echo -e "${YELLOW}Waiting for $service at $host:$port...${NC}"
    while ! nc -z $host $port 2>/dev/null; do
        sleep 1
    done
    echo -e "${GREEN}$service is ready!${NC}"
}

# Initialize Syncthing if enabled
if [ "$SYNCTHING_ENABLED" = "true" ]; then
    echo -e "${YELLOW}Initializing Syncthing...${NC}"
    
    # Start syncthing in background
    syncthing -no-browser -home=/data/sync/.config/syncthing &
    SYNCTHING_PID=$!
    
    # Wait for syncthing to be ready
    sleep 5
    
    # Configure syncthing via API
    if [ -f "/app/config/syncthing-config.json" ]; then
        curl -X POST -H "Content-Type: application/json" \
            -d @/app/config/syncthing-config.json \
            http://localhost:${SYNCTHING_API_PORT:-8385}/rest/config
    fi
    
    echo -e "${GREEN}Syncthing initialized${NC}"
fi

# Wait for dependencies
if [ -n "$REDIS_URL" ]; then
    # Extract host and port from Redis URL
    REDIS_HOST=$(echo $REDIS_URL | sed 's|redis://||' | cut -d: -f1)
    REDIS_PORT=$(echo $REDIS_URL | sed 's|redis://||' | cut -d: -f2 | cut -d/ -f1)
    wait_for_service $REDIS_HOST $REDIS_PORT "Redis"
fi

if [ -n "$POSTGRES_URL" ]; then
    # Extract host and port from PostgreSQL URL
    PG_HOST=$(echo $POSTGRES_URL | sed 's|postgresql://||' | cut -d@ -f2 | cut -d: -f1)
    PG_PORT=$(echo $POSTGRES_URL | sed 's|postgresql://||' | cut -d@ -f2 | cut -d: -f2 | cut -d/ -f1)
    wait_for_service $PG_HOST $PG_PORT "PostgreSQL"
    
    # Run database migrations
    echo -e "${YELLOW}Running database migrations...${NC}"
    if [ -f "/app/sql/migrations.sql" ]; then
        PGPASSWORD=$(echo $POSTGRES_URL | sed 's|postgresql://||' | cut -d: -f2 | cut -d@ -f1) \
        psql $POSTGRES_URL -f /app/sql/migrations.sql
    fi
fi

# Initialize WASM modules
echo -e "${YELLOW}Loading WASM modules...${NC}"
if [ "$WASM_SIMD_ENABLED" = "true" ] && [ -f "/app/ruv-swarm/npm/wasm/ruv_swarm_simd.wasm" ]; then
    export WASM_MODULE="/app/ruv-swarm/npm/wasm/ruv_swarm_simd.wasm"
    echo -e "${GREEN}SIMD-accelerated WASM loaded${NC}"
else
    export WASM_MODULE="/app/ruv-swarm/npm/wasm/ruv_swarm_wasm_bg.wasm"
    echo -e "${GREEN}Standard WASM loaded${NC}"
fi

# Start MCP server
echo -e "${GREEN}Starting MCP Server on port ${MCP_SERVER_PORT:-3000}...${NC}"

# Handle shutdown gracefully
trap 'echo -e "${YELLOW}Shutting down...${NC}"; kill $SYNCTHING_PID 2>/dev/null; exit 0' SIGTERM SIGINT

# Start the main application
if [ -f "/app/dist/index.js" ]; then
    exec node /app/dist/index.js
else
    exec node /app/ruv-swarm/npm/bin/ruv-swarm-mcp-server
fi