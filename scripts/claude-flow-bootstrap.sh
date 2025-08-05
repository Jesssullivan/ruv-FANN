#!/bin/bash
# Claude-Flow Alpha MCP Bootstrap Script for ruv-FANN

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}    ruv-FANN Claude-Flow Alpha MCP Bootstrap${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

# Check if running in container or host
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    echo -e "${YELLOW}Running in container environment${NC}"
    IN_CONTAINER=true
else
    echo -e "${YELLOW}Running on host system${NC}"
    IN_CONTAINER=false
fi

# Function to check command availability
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to install Claude-Flow
install_claude_flow() {
    echo -e "\n${BLUE}Installing Claude-Flow Alpha...${NC}"
    
    if check_command npx; then
        npx claude-flow@alpha --version &> /dev/null || npm install -g claude-flow@alpha
        echo -e "${GREEN}✓ Claude-Flow Alpha installed${NC}"
    else
        echo -e "${RED}✗ npm/npx not found. Please install Node.js first.${NC}"
        exit 1
    fi
}

# Function to configure MCP server
configure_mcp_server() {
    echo -e "\n${BLUE}Configuring MCP Server...${NC}"
    
    # Create MCP configuration
    cat > ~/.mcp/config.json << 'EOF'
{
  "servers": {
    "ruv-fann": {
      "command": "npx",
      "args": ["ruv-swarm", "mcp", "start"],
      "env": {
        "NODE_ENV": "production",
        "MCP_SERVER_PORT": "3000",
        "WASM_SIMD_ENABLED": "true"
      }
    },
    "claude-flow": {
      "command": "npx",
      "args": ["claude-flow@alpha", "mcp", "start"],
      "env": {
        "CLAUDE_FLOW_MODE": "server"
      }
    }
  },
  "tools": {
    "neural": ["neural_status", "neural_train", "neural_patterns"],
    "swarm": ["swarm_init", "agent_spawn", "task_orchestrate"],
    "daa": ["daa_init", "daa_agent_create", "daa_workflow_execute"]
  },
  "models": [
    "transformer", "lstm", "gru", "cnn", "autoencoder",
    "vae", "gnn", "resnet", "attention", "diffusion"
  ],
  "settings": {
    "maxConcurrentTools": 10,
    "requestTimeout": 30000,
    "enableMetrics": true,
    "enableLogging": true
  }
}
EOF
    
    echo -e "${GREEN}✓ MCP configuration created${NC}"
}

# Function to setup Claude Desktop integration
setup_claude_desktop() {
    echo -e "\n${BLUE}Setting up Claude Desktop integration...${NC}"
    
    local CLAUDE_CONFIG_DIR
    
    # Detect Claude Desktop config location
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # Windows
        CLAUDE_CONFIG_DIR="$APPDATA/Claude"
    else
        echo -e "${YELLOW}⚠ Unknown OS type: $OSTYPE${NC}"
        return
    fi
    
    # Create Claude config directory if it doesn't exist
    mkdir -p "$CLAUDE_CONFIG_DIR"
    
    # Create claude_desktop_config.json
    cat > "$CLAUDE_CONFIG_DIR/claude_desktop_config.json" << 'EOF'
{
  "mcpServers": {
    "ruv-fann": {
      "command": "node",
      "args": ["/app/ruv-swarm/npm/bin/ruv-swarm-mcp-server"],
      "env": {
        "NODE_ENV": "production",
        "MCP_SERVER_PORT": "3000",
        "WASM_SIMD_ENABLED": "true",
        "NEURAL_GPU_ENABLED": "false"
      }
    },
    "claude-flow-alpha": {
      "command": "npx",
      "args": ["claude-flow@alpha", "mcp", "start"],
      "env": {
        "CLAUDE_FLOW_MODE": "enhanced"
      }
    }
  }
}
EOF
    
    echo -e "${GREEN}✓ Claude Desktop configuration created${NC}"
    echo -e "${CYAN}  Location: $CLAUDE_CONFIG_DIR/claude_desktop_config.json${NC}"
}

# Function to test MCP connection
test_mcp_connection() {
    echo -e "\n${BLUE}Testing MCP connection...${NC}"
    
    # Start MCP server in background
    if [ "$IN_CONTAINER" = true ]; then
        node /app/ruv-swarm/npm/bin/ruv-swarm-mcp-server &
        MCP_PID=$!
    else
        npx ruv-swarm mcp start &
        MCP_PID=$!
    fi
    
    sleep 5
    
    # Test connection
    if curl -s http://localhost:3000/health > /dev/null; then
        echo -e "${GREEN}✓ MCP server is running${NC}"
        
        # Test a simple MCP call
        echo -e "${BLUE}Testing MCP tools...${NC}"
        npx claude-flow@alpha mcp test --server http://localhost:3000 || true
    else
        echo -e "${RED}✗ MCP server is not responding${NC}"
    fi
    
    # Stop test server
    kill $MCP_PID 2>/dev/null || true
}

# Function to create example usage script
create_example_script() {
    echo -e "\n${BLUE}Creating example usage script...${NC}"
    
    cat > ~/ruv-fann-example.js << 'EOF'
#!/usr/bin/env node

// Example usage of ruv-FANN with Claude-Flow MCP

import { MCPClient } from '@modelcontextprotocol/client';
import { RuvSwarm } from 'ruv-swarm';

async function main() {
    // Initialize MCP client
    const mcp = new MCPClient({
        serverUrl: 'http://localhost:3000',
        timeout: 30000
    });
    
    // Initialize swarm
    const swarmResult = await mcp.callTool('swarm_init', {
        topology: 'hierarchical',
        maxAgents: 8,
        strategy: 'adaptive'
    });
    console.log('Swarm initialized:', swarmResult);
    
    // Create DAA agent
    const agentResult = await mcp.callTool('daa_agent_create', {
        id: 'neural-analyst',
        capabilities: ['analysis', 'prediction', 'optimization'],
        cognitivePattern: 'adaptive',
        learningRate: 0.001,
        enableMemory: true
    });
    console.log('DAA agent created:', agentResult);
    
    // Train neural network
    const trainingResult = await mcp.callTool('neural_train', {
        modelType: 'transformer',
        epochs: 10,
        batchSize: 32
    });
    console.log('Neural training complete:', trainingResult);
    
    // Orchestrate task
    const taskResult = await mcp.callTool('task_orchestrate', {
        task: 'Analyze code patterns and suggest optimizations',
        priority: 'high',
        strategy: 'parallel'
    });
    console.log('Task orchestrated:', taskResult);
}

main().catch(console.error);
EOF
    
    chmod +x ~/ruv-fann-example.js
    echo -e "${GREEN}✓ Example script created: ~/ruv-fann-example.js${NC}"
}

# Function to display summary
display_summary() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}    Bootstrap Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${GREEN}Available MCP Tools:${NC}"
    echo -e "  ${YELLOW}• Neural:${NC} 27+ models with WASM acceleration"
    echo -e "  ${YELLOW}• Swarm:${NC} Hierarchical orchestration with 8 agents"
    echo -e "  ${YELLOW}• DAA:${NC} Autonomous agents with learning"
    echo -e "  ${YELLOW}• Syncthing:${NC} FANN network synchronization"
    
    echo -e "\n${GREEN}Quick Start Commands:${NC}"
    echo -e "  ${CYAN}# Start MCP server${NC}"
    if [ "$IN_CONTAINER" = true ]; then
        echo -e "  node /app/ruv-swarm/npm/bin/ruv-swarm-mcp-server"
    else
        echo -e "  npx ruv-swarm mcp start"
    fi
    
    echo -e "\n  ${CYAN}# Use with Claude Desktop${NC}"
    echo -e "  Open Claude Desktop → Settings → Developer → MCP Servers"
    
    echo -e "\n  ${CYAN}# Test with Claude-Flow${NC}"
    echo -e "  npx claude-flow@alpha mcp test"
    
    echo -e "\n  ${CYAN}# Run example script${NC}"
    echo -e "  node ~/ruv-fann-example.js"
    
    echo -e "\n${MAGENTA}Documentation:${NC}"
    echo -e "  • GitHub: https://github.com/ruvnet/claude-flow"
    echo -e "  • MCP Spec: https://modelcontextprotocol.io"
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

# Main execution
main() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    check_command node
    check_command npm
    check_command curl
    
    install_claude_flow
    configure_mcp_server
    setup_claude_desktop
    test_mcp_connection
    create_example_script
    display_summary
}

# Run main function
main