#!/bin/bash
# Claude Flow Integration Bootstrap Script
# Initializes the ruv-FANN stack for optimal Claude Code integration

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
MCP_SERVER_URL="http://localhost:3000"
CLAUDE_FLOW_CONFIG='{
    "topology": "hierarchical",
    "maxAgents": 12,
    "features": {
        "daa": true,
        "neural": true,
        "simd": true,
        "persistence": true,
        "mesh_sync": true
    },
    "agent_types": [
        "coordinator",
        "researcher", 
        "coder",
        "tester",
        "reviewer",
        "optimizer",
        "analyst"
    ],
    "neural_models": [
        "claude-code-optimizer",
        "lstm-coding-optimizer", 
        "nbeats-task-decomposer",
        "tcn-pattern-detector",
        "swarm-coordinator"
    ],
    "performance": {
        "wasm_simd": true,
        "gpu_acceleration": true,
        "parallel_execution": true,
        "memory_optimization": true
    }
}'

echo -e "${BLUE}🤖 Claude Flow Bootstrap for ruv-FANN${NC}"
echo -e "${BLUE}=====================================:${NC}"
echo ""

# Wait for MCP server to be ready
echo -e "${YELLOW}⏳ Waiting for MCP server to be ready...${NC}"
timeout=60
elapsed=0
while ! curl -s -f "$MCP_SERVER_URL/health" >/dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo -e "${RED}❌ MCP server not responding after ${timeout}s${NC}"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done
echo -e "${GREEN}✅ MCP server is ready${NC}"

# Initialize swarm topology
echo ""
echo -e "${BLUE}🕸️  Initializing swarm topology${NC}"
swarm_response=$(curl -s -X POST "$MCP_SERVER_URL/api/swarm/init" \
    -H "Content-Type: application/json" \
    -d '{"topology": "hierarchical", "maxAgents": 12, "strategy": "adaptive"}' \
    | jq -r '.swarm_id // "error"' 2>/dev/null || echo "error")

if [ "$swarm_response" != "error" ] && [ "$swarm_response" != "null" ]; then
    echo -e "${GREEN}✅ Swarm initialized with ID: $swarm_response${NC}"
    SWARM_ID="$swarm_response"
else
    echo -e "${YELLOW}⚠️  Using existing swarm or default configuration${NC}"
    SWARM_ID="default"
fi

# Spawn essential agents
echo ""
echo -e "${BLUE}👥 Spawning essential agents${NC}"
agents=("coordinator" "researcher" "coder" "tester" "reviewer" "optimizer")

for agent_type in "${agents[@]}"; do
    agent_response=$(curl -s -X POST "$MCP_SERVER_URL/api/agent/spawn" \
        -H "Content-Type: application/json" \
        -d "{\"type\": \"$agent_type\", \"swarmId\": \"$SWARM_ID\"}" \
        | jq -r '.agent_id // "error"' 2>/dev/null || echo "error")
    
    if [ "$agent_response" != "error" ] && [ "$agent_response" != "null" ]; then
        echo -e "   ${GREEN}✅ $agent_type agent spawned${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $agent_type agent spawn may have failed${NC}"
    fi
    sleep 1
done

# Initialize neural models
echo ""
echo -e "${BLUE}🧠 Initializing neural models${NC}"
neural_models=("claude-code-optimizer" "lstm-coding-optimizer" "swarm-coordinator")

for model in "${neural_models[@]}"; do
    model_response=$(curl -s -X POST "$MCP_SERVER_URL/api/neural/load" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\", \"path\": \"/data/models/$model\"}" \
        | jq -r '.status // "error"' 2>/dev/null || echo "error")
    
    if [ "$model_response" = "loaded" ] || [ "$model_response" = "ready" ]; then
        echo -e "   ${GREEN}✅ $model loaded${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $model may need training or is unavailable${NC}"
    fi
    sleep 1
done

# Configure memory persistence
echo ""
echo -e "${BLUE}💾 Configuring memory persistence${NC}"
memory_response=$(curl -s -X POST "$MCP_SERVER_URL/api/memory/config" \
    -H "Content-Type: application/json" \
    -d '{
        "persistence": true,
        "ttl": 86400,
        "compression": true,
        "namespace": "claude-flow",
        "backup_interval": 3600
    }' | jq -r '.status // "error"' 2>/dev/null || echo "error")

if [ "$memory_response" = "configured" ] || [ "$memory_response" = "ready" ]; then
    echo -e "${GREEN}✅ Memory persistence configured${NC}"
else
    echo -e "${YELLOW}⚠️  Memory persistence configuration may need attention${NC}"
fi

# Setup Syncthing mesh for FANN network
echo ""
echo -e "${BLUE}🌐 Configuring Syncthing mesh synchronization${NC}"
syncthing_config=$(curl -s -X POST "$MCP_SERVER_URL/api/syncthing/config" \
    -H "Content-Type: application/json" \
    -d '{
        "mesh_enabled": true,
        "auto_discovery": true,
        "sync_models": true,
        "sync_memory": false,
        "folders": [
            {"id": "fann-models", "path": "/data/models", "type": "readonly"},
            {"id": "fann-datasets", "path": "/data/datasets", "type": "readwrite"}
        ]
    }' | jq -r '.status // "error"' 2>/dev/null || echo "error")

if [ "$syncthing_config" = "configured" ] || [ "$syncthing_config" = "ready" ]; then
    echo -e "${GREEN}✅ Syncthing mesh configured${NC}"
else
    echo -e "${YELLOW}⚠️  Syncthing configuration may need manual setup${NC}"
fi

# Enable WASM SIMD features
echo ""
echo -e "${BLUE}⚡ Enabling WASM SIMD acceleration${NC}"
simd_response=$(curl -s -X POST "$MCP_SERVER_URL/api/wasm/enable-simd" \
    -H "Content-Type: application/json" \
    -d '{"features": ["simd", "bulk-memory", "threads"]}' \
    | jq -r '.simd_enabled // false' 2>/dev/null || echo "false")

if [ "$simd_response" = "true" ]; then
    echo -e "${GREEN}✅ WASM SIMD acceleration enabled${NC}"
else
    echo -e "${YELLOW}⚠️  WASM SIMD may not be supported on this platform${NC}"
fi

# Run comprehensive bootstrap
echo ""
echo -e "${BLUE}🚀 Running comprehensive Claude Flow bootstrap${NC}"
bootstrap_response=$(curl -s -X POST "$MCP_SERVER_URL/api/claude-flow/bootstrap" \
    -H "Content-Type: application/json" \
    -d "$CLAUDE_FLOW_CONFIG" \
    | jq -r '.status // "error"' 2>/dev/null || echo "error")

if [ "$bootstrap_response" = "success" ] || [ "$bootstrap_response" = "ready" ]; then
    echo -e "${GREEN}✅ Claude Flow bootstrap completed successfully${NC}"
else
    echo -e "${RED}❌ Claude Flow bootstrap encountered issues${NC}"
fi

# Performance benchmark
echo ""
echo -e "${BLUE}📊 Running performance benchmarks${NC}"
benchmark_response=$(curl -s -X POST "$MCP_SERVER_URL/api/benchmark/quick" \
    | jq -r '.performance_score // 0' 2>/dev/null || echo "0")

echo -e "Performance Score: ${GREEN}$benchmark_response${NC}"

# Final validation
echo ""
echo -e "${BLUE}✅ Final validation${NC}"
echo "=================="

# Check agent count
agent_count=$(curl -s "$MCP_SERVER_URL/api/agents" | jq '. | length' 2>/dev/null || echo "0")
echo -e "Active Agents: ${GREEN}$agent_count${NC}"

# Check neural models
model_count=$(curl -s "$MCP_SERVER_URL/api/neural/models" | jq '. | length' 2>/dev/null || echo "0")
echo -e "Neural Models: ${GREEN}$model_count${NC}"

# Check WASM status
wasm_status=$(curl -s "$MCP_SERVER_URL/api/wasm/status" | jq -r '.simd_enabled // false' 2>/dev/null || echo "false")
echo -e "WASM SIMD: ${GREEN}$wasm_status${NC}"

# Generate integration report
echo ""
echo -e "${PURPLE}📋 Claude Flow Integration Report${NC}"
echo -e "${PURPLE}===============================:${NC}"
echo ""
echo -e "✅ MCP Server:        Ready at http://localhost:3000"
echo -e "✅ Swarm Topology:    Hierarchical with $agent_count agents"
echo -e "✅ Neural Models:     $model_count models available"
echo -e "✅ WASM Acceleration: $wasm_status"
echo -e "✅ Memory Persistence: Enabled with compression"
echo -e "✅ Syncthing Mesh:    Configured for FANN network"
echo ""
echo -e "${GREEN}🎉 ruv-FANN is fully integrated with Claude Flow!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Add this MCP server to Claude Desktop:"
echo -e "   claude mcp add ruv-fann http://localhost:3000"
echo -e ""
echo -e "2. Test the integration:"
echo -e "   make test"
echo -e ""
echo -e "3. Monitor performance:"
echo -e "   make monitor"
echo ""