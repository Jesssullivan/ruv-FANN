#!/bin/bash
# Claude Flow + ruv-FANN Integrated Bootstrap Script
# Turnkey setup for MCP server integration

set -e

echo "🚀 Claude Flow + ruv-FANN Integration Bootstrap"
echo "=============================================="

# Check dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
    echo "✅ $1 found"
}

echo "Checking dependencies..."
check_dependency podman
check_dependency npm
check_dependency curl
check_dependency jq

# Build and deploy the stack
echo ""
echo "📦 Building and deploying ruv-FANN stack..."
make deploy

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to initialize..."
for i in {1..30}; do
    if curl -s http://localhost:3000/health | jq -e '.status == "healthy"' > /dev/null 2>&1; then
        echo "✅ Services are healthy!"
        break
    fi
    echo -n "."
    sleep 2
done

# Bootstrap MCP server
echo ""
echo "🔧 Bootstrapping MCP server..."
BOOTSTRAP_RESPONSE=$(curl -s -X POST http://localhost:3000/api/claude-flow/bootstrap \
    -H "Content-Type: application/json" \
    -d '{
        "config": {
            "topology": "hierarchical",
            "maxAgents": 8,
            "features": {
                "neural": true,
                "daa": true,
                "swarm": true,
                "memory": true,
                "github": true,
                "simd": true,
                "wasm": true
            }
        }
    }')

SWARM_ID=$(echo $BOOTSTRAP_RESPONSE | jq -r '.swarmId')
echo "✅ MCP server bootstrapped with swarm ID: $SWARM_ID"

# Configure Claude Flow MCP
echo ""
echo "🔗 Configuring Claude Flow MCP integration..."
cat > ~/.claude-flow-mcp.json << EOF
{
    "server": "http://localhost:3000",
    "swarmId": "$SWARM_ID",
    "endpoints": {
        "tools": "/api/tools",
        "execute": "/api/tools/execute",
        "session": "/api/session",
        "hooks": "/api/hooks"
    },
    "features": {
        "neural": true,
        "daa": true,
        "swarm": true,
        "memory": true,
        "github": true,
        "simd": true,
        "wasm": true
    }
}
EOF

# Install Claude Flow alpha if not present
if ! command -v claude-flow &> /dev/null; then
    echo ""
    echo "📥 Installing Claude Flow alpha..."
    npm install -g claude-flow@alpha
fi

# Add MCP server to Claude Flow
echo ""
echo "🎯 Adding MCP server to Claude Flow..."
claude-flow mcp add ruv-fann "http://localhost:3000" --config ~/.claude-flow-mcp.json

# Test the integration
echo ""
echo "🧪 Testing integration..."
echo "Testing tool discovery..."
curl -s http://localhost:3000/api/tools | jq '.tools[0:3]'

echo ""
echo "Testing swarm initialization..."
TEST_SWARM=$(curl -s -X POST http://localhost:3000/api/tools/execute \
    -H "Content-Type: application/json" \
    -d '{
        "tool": "swarm_init",
        "params": {
            "topology": "mesh",
            "maxAgents": 4
        }
    }')

if echo $TEST_SWARM | jq -e '.success == true' > /dev/null 2>&1; then
    echo "✅ Swarm initialization successful!"
else
    echo "⚠️  Swarm initialization test failed"
fi

# Display connection information
echo ""
echo "=============================================="
echo "🎉 Integration Complete!"
echo ""
echo "Services Running:"
echo "  • MCP Server:    http://localhost:3000"
echo "  • Syncthing UI:  http://localhost:8384"
echo "  • PostgreSQL:    localhost:5432"
echo "  • Redis:         localhost:6379"
echo ""
echo "Claude Flow Commands:"
echo "  • List tools:    claude-flow mcp list-tools ruv-fann"
echo "  • Execute tool:  claude-flow mcp execute ruv-fann <tool> <params>"
echo "  • Start swarm:   claude-flow swarm init --server ruv-fann"
echo ""
echo "Quick Test:"
echo "  curl http://localhost:3000/api/tools | jq"
echo ""
echo "To stop services: make stop"
echo "To view logs:     make logs"
echo "=============================================="