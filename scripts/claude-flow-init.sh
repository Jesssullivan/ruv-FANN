#!/bin/bash
# Claude-Flow + ruv-FANN Integration Bootstrap

set -e

echo "🚀 Initializing Claude-Flow with ruv-FANN MCP Server"

# Check if podman is running
if ! podman ps > /dev/null 2>&1; then
    echo "Starting Podman machine..."
    podman machine start
fi

# Deploy ruv-FANN stack
echo "📦 Deploying ruv-FANN stack..."
podman-compose -f podman-compose.production.yaml up -d

# Wait for services
echo "⏳ Waiting for services to start..."
until curl -s http://localhost:3000/health > /dev/null; do
    sleep 2
done

echo "✅ MCP Server ready"

# Install claude-flow if needed
if ! command -v claude-flow > /dev/null; then
    echo "📥 Installing claude-flow..."
    npm install -g claude-flow@alpha
fi

# Configure claude-flow
echo "🔧 Configuring claude-flow..."
cat > ~/.claude-flow/config.json << EOF
{
  "mcp_servers": [
    {
      "name": "ruv-fann",
      "url": "http://localhost:3000",
      "type": "http"
    }
  ],
  "session": {
    "persistence": true,
    "database": "postgresql://fann:fann123@localhost:5432/fanndb"
  }
}
EOF

# Initialize MCP connection
echo "🔗 Connecting to MCP server..."
claude-flow mcp connect ruv-fann

# Test tools
echo "🧪 Testing MCP tools..."
claude-flow mcp test --server ruv-fann

# Configure Claude Desktop
if [ -d "$HOME/Library/Application Support/Claude" ]; then
    echo "🖥️ Configuring Claude Desktop..."
    cp config/claude-desktop.json "$HOME/Library/Application Support/Claude/"
fi

echo ""
echo "✨ Integration complete!"
echo ""
echo "Available endpoints:"
echo "  MCP Server: http://localhost:3000"
echo "  Tools API:  http://localhost:3000/tools"
echo "  Models API: http://localhost:3000/models"
echo "  Syncthing:  http://localhost:8384"
echo ""
echo "Run 'claude-flow mcp list' to see available tools"