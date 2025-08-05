#!/bin/bash
# Claude-Flow Alpha MCP Bootstrap Integration for RUV-FANN + HuskyCats
# Seamlessly integrates the merged stack with Claude-Flow alpha MCP server

set -euo pipefail

# Script metadata
SCRIPT_NAME="Claude-Flow MCP Bootstrap"
SCRIPT_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $*${NC}" >&2
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" >&2
}

success() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*${NC}" >&2
}

# Configuration
MCP_SERVER_NAME="${MCP_SERVER_NAME:-ruv-fann-integrated}"
MCP_CONFIG_FILE="${MCP_CONFIG_FILE:-$PROJECT_ROOT/config/claude-mcp-integrated.json}"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.config/Claude Desktop}"
CLAUDE_MCP_CONFIG="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

# Service endpoints
FANN_CORE_URL="${FANN_CORE_URL:-http://localhost:8080}"
FANN_TRAINING_URL="${FANN_TRAINING_URL:-http://localhost:8082}"
FANN_INFERENCE_URL="${FANN_INFERENCE_URL:-http://localhost:8083}"
HUSKYCAT_MCP_URL="${HUSKYCAT_MCP_URL:-http://localhost:8084}"
SYNCTHING_URL="${SYNCTHING_URL:-http://localhost:8385}"

# Load environment if available
if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
    set -a
    source "$PROJECT_ROOT/.env.production"
    set +a
fi

# Check prerequisites
check_prerequisites() {
    log "Checking Claude-Flow MCP bootstrap prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in curl jq node npm; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check for claude-flow (optional but recommended)
    if ! command -v claude-flow >/dev/null 2>&1; then
        warn "claude-flow not found. Will create manual configuration."
        warn "Install with: npm install -g @anthropic/claude-flow@alpha"
    fi
    
    # Check if Claude Desktop is installed
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        warn "Claude Desktop config directory not found at: $CLAUDE_CONFIG_DIR"
        warn "Creating directory structure..."
        mkdir -p "$CLAUDE_CONFIG_DIR"
    fi
    
    success "Prerequisites check completed"
}

# Generate comprehensive MCP server configuration
generate_mcp_config() {
    log "Generating comprehensive MCP server configuration..."
    
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    
    cat > "$MCP_CONFIG_FILE" <<EOF
{
  "name": "$MCP_SERVER_NAME",
  "version": "2.0.0",
  "description": "Integrated RUV-FANN Neural Network Engine + HuskyCats Code Validation Platform",
  "author": "RUV Contributors",
  "license": "MIT OR Apache-2.0",
  
  "mcp": {
    "version": "2024-11-05",
    "capabilities": {
      "tools": {
        "listChanged": true
      },
      "resources": {
        "subscribe": true,
        "listChanged": true
      },
      "prompts": {
        "listChanged": true
      },
      "logging": {
        "level": "info"
      }
    }
  },
  
  "server": {
    "command": "node",
    "args": ["$PROJECT_ROOT/scripts/mcp-server-integrated.js"],
    "env": {
      "NODE_ENV": "production",
      "MCP_SERVER_NAME": "$MCP_SERVER_NAME",
      "FANN_CORE_URL": "$FANN_CORE_URL",
      "FANN_TRAINING_URL": "$FANN_TRAINING_URL",
      "FANN_INFERENCE_URL": "$FANN_INFERENCE_URL",
      "HUSKYCAT_MCP_URL": "$HUSKYCAT_MCP_URL",
      "SYNCTHING_URL": "$SYNCTHING_URL",
      "SYNCTHING_API_KEY": "${SYNCTHING_API_KEY:-}",
      "BEARER_TOKEN": "${BEARER_TOKEN:-}",
      "LOG_LEVEL": "info",
      "ENABLE_METRICS": "true",
      "ENABLE_TRACING": "true"
    }
  },
  
  "tools": [
    {
      "name": "fann_create_neural_network",
      "description": "Create a new FANN neural network with specified architecture",
      "inputSchema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "Name of the neural network"
          },
          "layers": {
            "type": "array",
            "items": {
              "type": "integer"
            },
            "description": "Array of layer sizes (e.g., [784, 128, 64, 10])"
          },
          "activation": {
            "type": "string",
            "enum": ["sigmoid", "tanh", "relu", "linear"],
            "default": "sigmoid",
            "description": "Activation function"
          },
          "learning_rate": {
            "type": "number",
            "default": 0.01,
            "description": "Learning rate for training"
          }
        },
        "required": ["name", "layers"]
      }
    },
    {
      "name": "fann_train_network",
      "description": "Train a FANN neural network with provided dataset",
      "inputSchema": {
        "type": "object",
        "properties": {
          "network_id": {
            "type": "string",
            "description": "ID of the neural network to train"
          },
          "dataset_path": {
            "type": "string",
            "description": "Path to training dataset"
          },
          "epochs": {
            "type": "integer",
            "default": 1000,
            "description": "Number of training epochs"
          },
          "validation_split": {
            "type": "number",
            "default": 0.2,
            "description": "Fraction of data to use for validation"
          },
          "distributed": {
            "type": "boolean",
            "default": true,
            "description": "Enable distributed training"
          }
        },
        "required": ["network_id", "dataset_path"]
      }
    },
    {
      "name": "fann_inference",
      "description": "Run inference on a trained FANN neural network",
      "inputSchema": {
        "type": "object",
        "properties": {
          "network_id": {
            "type": "string",
            "description": "ID of the trained neural network"
          },
          "input_data": {
            "type": "array",
            "items": {
              "type": "number"
            },
            "description": "Input data for inference"
          },
          "batch_size": {
            "type": "integer",
            "default": 32,
            "description": "Batch size for inference"
          }
        },
        "required": ["network_id", "input_data"]
      }
    },
    {
      "name": "fann_get_network_info",
      "description": "Get detailed information about a neural network",
      "inputSchema": {
        "type": "object",
        "properties": {
          "network_id": {
            "type": "string",
            "description": "ID of the neural network"
          }
        },
        "required": ["network_id"]
      }
    },
    {
      "name": "fann_list_networks",
      "description": "List all available neural networks",
      "inputSchema": {
        "type": "object",
        "properties": {
          "status": {
            "type": "string",
            "enum": ["all", "trained", "training", "untrained"],
            "default": "all",
            "description": "Filter networks by status"
          }
        }
      }
    },
    {
      "name": "huskycat_validate_code",
      "description": "Validate code using HuskyCat's comprehensive linting tools",
      "inputSchema": {
        "type": "object",
        "properties": {
          "code": {
            "type": "string",
            "description": "Code to validate"
          },
          "language": {
            "type": "string",
            "enum": ["python", "javascript", "typescript", "shell", "yaml", "dockerfile"],
            "description": "Programming language of the code"
          },
          "tools": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Specific tools to use (e.g., ['black', 'flake8', 'mypy'])"
          },
          "auto_fix": {
            "type": "boolean",
            "default": false,
            "description": "Automatically fix issues where possible"
          },
          "severity": {
            "type": "string",
            "enum": ["info", "warning", "error"],
            "default": "warning",
            "description": "Minimum severity level to report"
          }
        },
        "required": ["code", "language"]
      }
    },
    {
      "name": "huskycat_validate_repository",
      "description": "Validate an entire repository using HuskyCat tools",
      "inputSchema": {
        "type": "object",
        "properties": {
          "repository_path": {
            "type": "string",
            "description": "Path to the repository to validate"
          },
          "file_patterns": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "default": ["**/*.py", "**/*.js", "**/*.ts", "**/*.sh", "**/*.yml", "**/*.yaml"],
            "description": "File patterns to include in validation"
          },
          "exclude_patterns": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "default": ["**/node_modules/**", "**/__pycache__/**", "**/venv/**", "**/dist/**"],
            "description": "File patterns to exclude from validation"
          },
          "parallel": {
            "type": "boolean",
            "default": true,
            "description": "Enable parallel validation"
          }
        },
        "required": ["repository_path"]
      }
    },
    {
      "name": "syncthing_sync_repository",
      "description": "Synchronize a repository using Syncthing mesh network",
      "inputSchema": {
        "type": "object",
        "properties": {
          "repository_path": {
            "type": "string",
            "description": "Local path to the repository"
          },
          "sync_mode": {
            "type": "string",
            "enum": ["bidirectional", "send_only", "receive_only"],
            "default": "bidirectional",
            "description": "Synchronization mode"
          },
          "devices": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "Device IDs to sync with (empty for all)"
          },
          "immediate": {
            "type": "boolean",
            "default": false,
            "description": "Force immediate synchronization"
          }
        },
        "required": ["repository_path"]
      }
    },
    {
      "name": "syncthing_get_sync_status",
      "description": "Get synchronization status for repositories",
      "inputSchema": {
        "type": "object",
        "properties": {
          "folder_id": {
            "type": "string",
            "description": "Specific folder ID to check (optional)"
          }
        }
      }
    },
    {
      "name": "system_get_metrics",
      "description": "Get comprehensive system metrics from all services",
      "inputSchema": {
        "type": "object",
        "properties": {
          "service": {
            "type": "string",
            "enum": ["all", "fann-core", "fann-training", "fann-inference", "huskycat-mcp", "syncthing"],
            "default": "all",
            "description": "Specific service to get metrics for"
          },
          "time_range": {
            "type": "string",
            "default": "5m",
            "description": "Time range for metrics (e.g., '5m', '1h', '1d')"
          }
        }
      }
    },
    {
      "name": "system_health_check",
      "description": "Perform comprehensive health check on all services",
      "inputSchema": {
        "type": "object",
        "properties": {
          "deep_check": {
            "type": "boolean",
            "default": false,
            "description": "Perform deep health checks including connectivity tests"
          }
        }
      }
    }
  ],
  
  "resources": [
    {
      "uri": "fann://networks",
      "name": "FANN Neural Networks",
      "description": "List of all neural networks in the system",
      "mimeType": "application/json"
    },
    {
      "uri": "fann://models/{id}",
      "name": "FANN Model Details",
      "description": "Detailed information about a specific neural network model",
      "mimeType": "application/json"
    },
    {
      "uri": "fann://training/{id}",
      "name": "Training Progress",
      "description": "Real-time training progress and metrics",
      "mimeType": "application/json"
    },
    {
      "uri": "huskycat://validation/{id}",
      "name": "Validation Results",
      "description": "Code validation results and reports",
      "mimeType": "application/json"
    },
    {
      "uri": "syncthing://folders",
      "name": "Syncthing Folders",
      "description": "List of synchronized folders and their status",
      "mimeType": "application/json"
    },
    {
      "uri": "syncthing://devices",
      "name": "Syncthing Devices",
      "description": "List of connected devices in the mesh network",
      "mimeType": "application/json"
    },
    {
      "uri": "system://metrics",
      "name": "System Metrics",
      "description": "Comprehensive system performance metrics",
      "mimeType": "application/json"
    },
    {
      "uri": "system://logs",
      "name": "System Logs",
      "description": "Aggregated logs from all services",
      "mimeType": "text/plain"
    }
  ],
  
  "prompts": [
    {
      "name": "neural_network_architect",
      "description": "Expert neural network architecture design assistant",
      "arguments": [
        {
          "name": "problem_type",
          "description": "Type of problem to solve (classification, regression, etc.)",
          "required": true
        },
        {
          "name": "data_shape",
          "description": "Shape of input data",
          "required": true
        },
        {
          "name": "performance_requirements",
          "description": "Performance requirements (accuracy, speed, memory)",
          "required": false
        }
      ]
    },
    {
      "name": "code_quality_reviewer",
      "description": "Comprehensive code quality review and improvement suggestions",
      "arguments": [
        {
          "name": "language",
          "description": "Programming language",
          "required": true
        },
        {
          "name": "code_type",
          "description": "Type of code (library, application, script, etc.)",
          "required": false
        },
        {
          "name": "focus_areas",
          "description": "Specific areas to focus on (security, performance, maintainability)",
          "required": false
        }
      ]
    },
    {
      "name": "distributed_system_optimizer",
      "description": "Optimize distributed neural network training and inference",
      "arguments": [
        {
          "name": "current_setup",
          "description": "Current system configuration",
          "required": true
        },
        {
          "name": "bottlenecks",
          "description": "Known performance bottlenecks",
          "required": false
        },
        {
          "name": "scaling_requirements",
          "description": "Scaling requirements and constraints",
          "required": false
        }
      ]
    }
  ],
  
  "integration": {
    "claude_flow": {
      "version": "alpha",
      "features": {
        "auto_completion": true,
        "context_awareness": true,
        "multi_modal": true,
        "real_time_feedback": true
      },
      "hooks": {
        "pre_task": "$PROJECT_ROOT/scripts/claude-hooks-pre.sh",
        "post_task": "$PROJECT_ROOT/scripts/claude-hooks-post.sh",
        "pre_edit": "$PROJECT_ROOT/scripts/claude-hooks-pre-edit.sh",
        "post_edit": "$PROJECT_ROOT/scripts/claude-hooks-post-edit.sh"
      }
    }
  }
}
EOF
    
    success "MCP configuration generated: $MCP_CONFIG_FILE"
}

# Create the integrated MCP server implementation
create_mcp_server() {
    log "Creating integrated MCP server implementation..."
    
    cat > "$PROJECT_ROOT/scripts/mcp-server-integrated.js" <<'EOF'
#!/usr/bin/env node

/**
 * RUV-FANN + HuskyCats Integrated MCP Server
 * Provides unified interface for neural network operations and code validation
 */

const { Server } = require('@modelcontextprotocol/sdk/server');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio');
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const config = {
  name: process.env.MCP_SERVER_NAME || 'ruv-fann-integrated',
  version: '2.0.0',
  endpoints: {
    fannCore: process.env.FANN_CORE_URL || 'http://localhost:8080',
    fannTraining: process.env.FANN_TRAINING_URL || 'http://localhost:8082',
    fannInference: process.env.FANN_INFERENCE_URL || 'http://localhost:8083',
    huskycatMcp: process.env.HUSKYCAT_MCP_URL || 'http://localhost:8084',
    syncthing: process.env.SYNCTHING_URL || 'http://localhost:8385'
  },
  auth: {
    bearerToken: process.env.BEARER_TOKEN,
    syncthingApiKey: process.env.SYNCTHING_API_KEY
  },
  features: {
    metrics: process.env.ENABLE_METRICS === 'true',
    tracing: process.env.ENABLE_TRACING === 'true'
  }
};

// Utility functions
const makeRequest = async (url, options = {}) => {
  const headers = {
    'Content-Type': 'application/json',
    'User-Agent': `${config.name}/${config.version}`,
    ...options.headers
  };

  if (config.auth.bearerToken) {
    headers['Authorization'] = `Bearer ${config.auth.bearerToken}`;
  }

  try {
    const response = await axios({
      url,
      method: options.method || 'GET',
      headers,
      data: options.data,
      timeout: options.timeout || 30000
    });
    return response.data;
  } catch (error) {
    console.error(`Request failed for ${url}:`, error.message);
    throw new Error(`API request failed: ${error.response?.data?.message || error.message}`);
  }
};

const makeSyncthingRequest = async (endpoint, options = {}) => {
  const url = `${config.endpoints.syncthing}/rest/${endpoint}`;
  const headers = {
    'X-API-Key': config.auth.syncthingApiKey,
    ...options.headers
  };
  return makeRequest(url, { ...options, headers });
};

// MCP Server implementation
class IntegratedMCPServer {
  constructor() {
    this.server = new Server({
      name: config.name,
      version: config.version
    }, {
      capabilities: {
        tools: { listChanged: true },
        resources: { subscribe: true, listChanged: true },
        prompts: { listChanged: true },
        logging: { level: 'info' }
      }
    });

    this.setupHandlers();
  }

  setupHandlers() {
    // Tool handlers
    this.server.setRequestHandler('tools/list', this.handleListTools.bind(this));
    this.server.setRequestHandler('tools/call', this.handleCallTool.bind(this));
    
    // Resource handlers
    this.server.setRequestHandler('resources/list', this.handleListResources.bind(this));
    this.server.setRequestHandler('resources/read', this.handleReadResource.bind(this));
    
    // Prompt handlers
    this.server.setRequestHandler('prompts/list', this.handleListPrompts.bind(this));
    this.server.setRequestHandler('prompts/get', this.handleGetPrompt.bind(this));
  }

  async handleListTools() {
    return {
      tools: [
        {
          name: 'fann_create_neural_network',
          description: 'Create a new FANN neural network with specified architecture',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Name of the neural network' },
              layers: { type: 'array', items: { type: 'integer' }, description: 'Array of layer sizes' },
              activation: { type: 'string', enum: ['sigmoid', 'tanh', 'relu', 'linear'], default: 'sigmoid' },
              learning_rate: { type: 'number', default: 0.01 }
            },
            required: ['name', 'layers']
          }
        },
        {
          name: 'fann_train_network',
          description: 'Train a FANN neural network with provided dataset',
          inputSchema: {
            type: 'object',
            properties: {
              network_id: { type: 'string', description: 'ID of the neural network to train' },
              dataset_path: { type: 'string', description: 'Path to training dataset' },
              epochs: { type: 'integer', default: 1000 },
              validation_split: { type: 'number', default: 0.2 },
              distributed: { type: 'boolean', default: true }
            },
            required: ['network_id', 'dataset_path']
          }
        },
        {
          name: 'fann_inference',
          description: 'Run inference on a trained FANN neural network',
          inputSchema: {
            type: 'object',
            properties: {
              network_id: { type: 'string', description: 'ID of the trained neural network' },
              input_data: { type: 'array', items: { type: 'number' }, description: 'Input data for inference' },
              batch_size: { type: 'integer', default: 32 }
            },
            required: ['network_id', 'input_data']
          }
        },
        {
          name: 'huskycat_validate_code',
          description: 'Validate code using HuskyCat comprehensive linting tools',
          inputSchema: {
            type: 'object',
            properties: {
              code: { type: 'string', description: 'Code to validate' },
              language: { type: 'string', enum: ['python', 'javascript', 'typescript', 'shell', 'yaml', 'dockerfile'] },
              tools: { type: 'array', items: { type: 'string' } },
              auto_fix: { type: 'boolean', default: false },
              severity: { type: 'string', enum: ['info', 'warning', 'error'], default: 'warning' }
            },
            required: ['code', 'language']
          }
        },
        {
          name: 'syncthing_sync_repository',
          description: 'Synchronize a repository using Syncthing mesh network',
          inputSchema: {
            type: 'object',
            properties: {
              repository_path: { type: 'string', description: 'Local path to the repository' },
              sync_mode: { type: 'string', enum: ['bidirectional', 'send_only', 'receive_only'], default: 'bidirectional' },
              devices: { type: 'array', items: { type: 'string' } },
              immediate: { type: 'boolean', default: false }
            },
            required: ['repository_path']
          }
        },
        {
          name: 'system_health_check',
          description: 'Perform comprehensive health check on all services',
          inputSchema: {
            type: 'object',
            properties: {
              deep_check: { type: 'boolean', default: false }
            }
          }
        }
      ]
    };
  }

  async handleCallTool(request) {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        case 'fann_create_neural_network':
          return await this.createNeuralNetwork(args);
        case 'fann_train_network':
          return await this.trainNetwork(args);
        case 'fann_inference':
          return await this.runInference(args);
        case 'huskycat_validate_code':
          return await this.validateCode(args);
        case 'syncthing_sync_repository':
          return await this.syncRepository(args);
        case 'system_health_check':
          return await this.performHealthCheck(args);
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Error executing tool ${name}: ${error.message}`
        }],
        isError: true
      };
    }
  }

  async createNeuralNetwork(args) {
    const result = await makeRequest(`${config.endpoints.fannCore}/api/v1/networks`, {
      method: 'POST',
      data: {
        name: args.name,
        architecture: {
          layers: args.layers,
          activation: args.activation || 'sigmoid',
          learning_rate: args.learning_rate || 0.01
        }
      }
    });

    return {
      content: [{
        type: 'text',
        text: `Successfully created neural network "${args.name}" with ID: ${result.id}\nArchitecture: ${args.layers.join(' -> ')}\nActivation: ${args.activation || 'sigmoid'}`
      }]
    };
  }

  async trainNetwork(args) {
    const result = await makeRequest(`${config.endpoints.fannTraining}/api/v1/training/start`, {
      method: 'POST',
      data: {
        network_id: args.network_id,
        dataset_path: args.dataset_path,
        config: {
          epochs: args.epochs || 1000,
          validation_split: args.validation_split || 0.2,
          distributed: args.distributed !== false
        }
      }
    });

    return {
      content: [{
        type: 'text',
        text: `Training started for network ${args.network_id}\nJob ID: ${result.job_id}\nEpochs: ${args.epochs || 1000}\nDataset: ${args.dataset_path}`
      }]
    };
  }

  async runInference(args) {
    const result = await makeRequest(`${config.endpoints.fannInference}/api/v1/inference`, {
      method: 'POST',
      data: {
        network_id: args.network_id,
        input_data: args.input_data,
        batch_size: args.batch_size || 32
      }
    });

    return {
      content: [{
        type: 'text',
        text: `Inference completed for network ${args.network_id}\nInput shape: [${args.input_data.length}]\nOutput: ${JSON.stringify(result.predictions, null, 2)}\nProcessing time: ${result.processing_time_ms}ms`
      }]
    };
  }

  async validateCode(args) {
    const result = await makeRequest(`${config.endpoints.huskycatMcp}/api/v1/validate`, {
      method: 'POST',
      data: {
        code: args.code,
        language: args.language,
        tools: args.tools,
        options: {
          auto_fix: args.auto_fix || false,
          min_severity: args.severity || 'warning'
        }
      }
    });

    const issueCount = result.issues ? result.issues.length : 0;
    const summary = result.summary || {};

    return {
      content: [{
        type: 'text',
        text: `Code validation completed for ${args.language}\nIssues found: ${issueCount}\nErrors: ${summary.errors || 0}\nWarnings: ${summary.warnings || 0}\nTools used: ${(args.tools || result.tools_used || []).join(', ')}\n\n${result.report || 'No detailed report available.'}`
      }]
    };
  }

  async syncRepository(args) {
    // First, add repository to Syncthing if not exists
    const result = await makeSyncthingRequest('system/config', { method: 'GET' });
    
    // Trigger sync
    await makeSyncthingRequest(`db/scan?folder=${encodeURIComponent(args.repository_path)}`, {
      method: 'POST'
    });

    return {
      content: [{
        type: 'text',
        text: `Repository synchronization initiated\nPath: ${args.repository_path}\nMode: ${args.sync_mode || 'bidirectional'}\nDevices: ${args.devices ? args.devices.join(', ') : 'all'}`
      }]
    };
  }

  async performHealthCheck(args) {
    const services = [
      { name: 'FANN Core', url: `${config.endpoints.fannCore}/health` },
      { name: 'FANN Training', url: `${config.endpoints.fannTraining}/health` },
      { name: 'FANN Inference', url: `${config.endpoints.fannInference}/health` },
      { name: 'HuskyCat MCP', url: `${config.endpoints.huskycatMcp}/health` },
      { name: 'Syncthing', url: `${config.endpoints.syncthing}/rest/system/ping` }
    ];

    const results = await Promise.allSettled(
      services.map(async (service) => {
        try {
          const headers = service.name === 'Syncthing' ? { 'X-API-Key': config.auth.syncthingApiKey } : {};
          await makeRequest(service.url, { headers, timeout: 5000 });
          return { name: service.name, status: 'healthy', response_time: 'OK' };
        } catch (error) {
          return { name: service.name, status: 'unhealthy', error: error.message };
        }
      })
    );

    const healthResults = results.map((result, index) => 
      result.status === 'fulfilled' ? result.value : 
      { name: services[index].name, status: 'unhealthy', error: result.reason.message }
    );

    const healthyCount = healthResults.filter(r => r.status === 'healthy').length;
    const totalServices = healthResults.length;

    return {
      content: [{
        type: 'text',
        text: `System Health Check Results\n${'='.repeat(30)}\nOverall Status: ${healthyCount === totalServices ? '✅ HEALTHY' : '⚠️ DEGRADED'}\nServices: ${healthyCount}/${totalServices} healthy\n\n${healthResults.map(r => 
          `${r.status === 'healthy' ? '✅' : '❌'} ${r.name}: ${r.status}${r.error ? ` (${r.error})` : ''}`
        ).join('\n')}`
      }]
    };
  }

  async handleListResources() {
    return {
      resources: [
        { uri: 'fann://networks', name: 'FANN Neural Networks', mimeType: 'application/json' },
        { uri: 'huskycat://validation-reports', name: 'Validation Reports', mimeType: 'application/json' },
        { uri: 'syncthing://folders', name: 'Syncthing Folders', mimeType: 'application/json' },
        { uri: 'system://metrics', name: 'System Metrics', mimeType: 'application/json' }
      ]
    };
  }

  async handleReadResource(request) {
    const { uri } = request.params;
    
    if (uri.startsWith('fann://')) {
      const path = uri.replace('fann://', '');
      const data = await makeRequest(`${config.endpoints.fannCore}/api/v1/${path}`);
      return {
        contents: [{
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(data, null, 2)
        }]
      };
    }
    
    throw new Error(`Unsupported resource URI: ${uri}`);
  }

  async handleListPrompts() {
    return {
      prompts: [
        {
          name: 'neural_network_architect',
          description: 'Expert neural network architecture design assistant',
          arguments: [
            { name: 'problem_type', description: 'Type of problem to solve', required: true },
            { name: 'data_shape', description: 'Shape of input data', required: true }
          ]
        }
      ]
    };
  }

  async handleGetPrompt(request) {
    const { name, arguments: args } = request.params;
    
    if (name === 'neural_network_architect') {
      return {
        description: 'Neural Network Architecture Design Assistant',
        messages: [{
          role: 'user',
          content: {
            type: 'text',
            text: `Design a neural network for ${args.problem_type} with input shape ${args.data_shape}. Consider performance requirements and provide specific architecture recommendations.`
          }
        }]
      };
    }
    
    throw new Error(`Unknown prompt: ${name}`);
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error(`${config.name} MCP Server v${config.version} started`);
  }
}

// Start the server
if (require.main === module) {
  const server = new IntegratedMCPServer();
  server.start().catch(console.error);
}

module.exports = IntegratedMCPServer;
EOF

    chmod +x "$PROJECT_ROOT/scripts/mcp-server-integrated.js"
    success "Integrated MCP server created"
}

# Install Node.js dependencies for MCP server
install_dependencies() {
    log "Installing Node.js dependencies for MCP server..."
    
    local package_json="$PROJECT_ROOT/scripts/package.json"
    
    cat > "$package_json" <<EOF
{
  "name": "ruv-fann-mcp-server",
  "version": "2.0.0",
  "description": "Integrated MCP server for RUV-FANN + HuskyCats",
  "main": "mcp-server-integrated.js",
  "scripts": {
    "start": "node mcp-server-integrated.js",
    "dev": "nodemon mcp-server-integrated.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
EOF
    
    cd "$PROJECT_ROOT/scripts"
    npm install
    
    success "Dependencies installed"
}

# Update Claude Desktop configuration
update_claude_config() {
    log "Updating Claude Desktop configuration..."
    
    # Backup existing config if it exists
    if [[ -f "$CLAUDE_MCP_CONFIG" ]]; then
        cp "$CLAUDE_MCP_CONFIG" "$CLAUDE_MCP_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
        log "Backed up existing Claude config"
    fi
    
    # Create or update Claude Desktop config
    local temp_config
    temp_config=$(mktemp)
    
    if [[ -f "$CLAUDE_MCP_CONFIG" ]]; then
        # Merge with existing config
        jq --arg server_name "$MCP_SERVER_NAME" \
           --arg server_command "node" \
           --argjson server_args "[\"$PROJECT_ROOT/scripts/mcp-server-integrated.js\"]" \
           --argjson server_env "{
             \"NODE_ENV\": \"production\",
             \"FANN_CORE_URL\": \"$FANN_CORE_URL\",
             \"FANN_TRAINING_URL\": \"$FANN_TRAINING_URL\",
             \"FANN_INFERENCE_URL\": \"$FANN_INFERENCE_URL\",
             \"HUSKYCAT_MCP_URL\": \"$HUSKYCAT_MCP_URL\",
             \"SYNCTHING_URL\": \"$SYNCTHING_URL\",
             \"SYNCTHING_API_KEY\": \"${SYNCTHING_API_KEY:-}\",
             \"BEARER_TOKEN\": \"${BEARER_TOKEN:-}\"
           }" \
           '.mcpServers[$server_name] = {
             "command": $server_command,
             "args": $server_args,
             "env": $server_env
           }' "$CLAUDE_MCP_CONFIG" > "$temp_config"
    else
        # Create new config
        jq -n --arg server_name "$MCP_SERVER_NAME" \
              --arg server_command "node" \
              --argjson server_args "[\"$PROJECT_ROOT/scripts/mcp-server-integrated.js\"]" \
              --argjson server_env "{
                \"NODE_ENV\": \"production\",
                \"FANN_CORE_URL\": \"$FANN_CORE_URL\",
                \"FANN_TRAINING_URL\": \"$FANN_TRAINING_URL\",
                \"FANN_INFERENCE_URL\": \"$FANN_INFERENCE_URL\",
                \"HUSKYCAT_MCP_URL\": \"$HUSKYCAT_MCP_URL\",
                \"SYNCTHING_URL\": \"$SYNCTHING_URL\",
                \"SYNCTHING_API_KEY\": \"${SYNCTHING_API_KEY:-}\",
                \"BEARER_TOKEN\": \"${BEARER_TOKEN:-}\"
              }" \
              '{
                mcpServers: {
                  ($server_name): {
                    command: $server_command,
                    args: $server_args,
                    env: $server_env
                  }
                }
              }' > "$temp_config"
    fi
    
    mv "$temp_config" "$CLAUDE_MCP_CONFIG"
    success "Claude Desktop configuration updated"
}

# Test MCP server connection
test_mcp_server() {
    log "Testing MCP server connection..."
    
    # Start MCP server in background for testing
    cd "$PROJECT_ROOT/scripts"
    timeout 10s node mcp-server-integrated.js < /dev/null > /tmp/mcp-test.log 2>&1 &
    local mcp_pid=$!
    
    sleep 2
    
    if kill -0 "$mcp_pid" 2>/dev/null; then
        success "MCP server started successfully"
        kill "$mcp_pid" 2>/dev/null || true
    else
        error "MCP server failed to start"
        warn "Check logs at: /tmp/mcp-test.log"
        return 1
    fi
}

# Verify services are running
verify_services() {
    log "Verifying integrated services are running..."
    
    local failed_services=()
    
    # Check each service
    if ! curl -sf "$FANN_CORE_URL/health" >/dev/null 2>&1; then
        failed_services+=("FANN Core ($FANN_CORE_URL)")
    fi
    
    if ! curl -sf "$HUSKYCAT_MCP_URL/health" >/dev/null 2>&1; then
        failed_services+=("HuskyCat MCP ($HUSKYCAT_MCP_URL)")
    fi
    
    if ! curl -sf -H "X-API-Key: ${SYNCTHING_API_KEY}" "$SYNCTHING_URL/rest/system/ping" >/dev/null 2>&1; then
        failed_services+=("Syncthing ($SYNCTHING_URL)")
    fi
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        success "All services are running and accessible"
    else
        error "Some services are not accessible:"
        printf '%s\n' "${failed_services[@]}"
        warn "Start the integrated stack with: $PROJECT_ROOT/scripts/bootstrap-integrated-stack.sh"
        return 1
    fi
}

# Display integration summary
display_summary() {
    echo -e "\n${PURPLE}=== Claude-Flow MCP Bootstrap Complete ===${NC}"
    echo -e "${BLUE}MCP Server:${NC} $MCP_SERVER_NAME"
    echo -e "${BLUE}Configuration:${NC} $MCP_CONFIG_FILE"
    echo -e "${BLUE}Claude Config:${NC} $CLAUDE_MCP_CONFIG"
    echo ""
    echo -e "${BLUE}Integrated Services:${NC}"
    echo "🧠 FANN Core:         $FANN_CORE_URL"
    echo "🏋️  FANN Training:     $FANN_TRAINING_URL"
    echo "⚡ FANN Inference:    $FANN_INFERENCE_URL"
    echo "🐱 HuskyCat MCP:      $HUSKYCAT_MCP_URL"
    echo "🔄 Syncthing:         $SYNCTHING_URL"
    echo ""
    echo -e "${BLUE}Available Tools:${NC}"
    echo "• fann_create_neural_network"
    echo "• fann_train_network"
    echo "• fann_inference"
    echo "• huskycat_validate_code"
    echo "• syncthing_sync_repository"
    echo "• system_health_check"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Restart Claude Desktop to load the new MCP server"
    echo "2. Test integration by asking Claude to create a neural network"
    echo "3. Use '@$MCP_SERVER_NAME' to reference specific tools"
    echo ""
    echo -e "${BLUE}Testing:${NC}"
    echo "node $PROJECT_ROOT/scripts/mcp-server-integrated.js"
    echo -e "${PURPLE}==========================================${NC}\n"
}

# Main execution
main() {
    echo -e "${CYAN}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo -e "${CYAN}Integrating RUV-FANN + HuskyCats with Claude-Flow Alpha${NC}\n"
    
    check_prerequisites
    generate_mcp_config
    create_mcp_server
    install_dependencies
    update_claude_config
    test_mcp_server
    verify_services
    display_summary
    
    success "Claude-Flow MCP bootstrap integration completed successfully!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF