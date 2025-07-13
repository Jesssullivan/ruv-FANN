# Claude Flow Integration Guide

This guide explains how to integrate ruv-swarm with claude-flow using the new hybrid server architecture.

## Overview

The ruv-swarm hybrid server supports both:
- **stdio protocol** - For Claude Code MCP integration
- **HTTP/SSE protocol** - For claude-flow persistent service integration

## Architecture

### Problem Solved

The original stdio-only implementation would immediately close when stdin ends, which breaks functionality for claude-flow that expects a persistent service. The hybrid architecture solves this by:

1. **Persistent HTTP Server** - Runs continuously for claude-flow
2. **SSE (Server-Sent Events)** - Real-time updates and streaming
3. **RESTful API** - Tool invocation endpoints
4. **Daemon Mode** - Background service operation

### Modes of Operation

1. **Stdio Mode** (default) - For Claude Code
   ```bash
   ruv-swarm mcp start
   ```

2. **HTTP Mode** - For claude-flow
   ```bash
   ruv-swarm mcp start --http --port 8080
   ```

3. **Hybrid Mode** - Both protocols simultaneously
   ```bash
   ruv-swarm mcp start --hybrid
   ```

4. **Daemon Mode** - Background service
   ```bash
   ruv-swarm mcp start --http --daemon
   ```

## HTTP/SSE API Reference

### Base URL
```
http://localhost:8080
```

### Endpoints

#### Health Check
```http
GET /health
```

Response:
```json
{
  "status": "ok",
  "version": "1.0.18",
  "mode": "hybrid",
  "timestamp": "2025-07-13T18:00:00.000Z"
}
```

#### SSE Event Stream
```http
GET /events
```

Event types:
- `connected` - Initial connection
- `swarm:update` - Swarm status changes
- `agent:spawn` - New agent created
- `task:update` - Task progress
- `tool:executed` - Tool execution events
- `performance:metrics` - Performance data

Example client:
```javascript
const eventSource = new EventSource('http://localhost:8080/events');

eventSource.addEventListener('swarm:update', (event) => {
  const data = JSON.parse(event.data);
  console.log('Swarm update:', data);
});

eventSource.addEventListener('agent:spawn', (event) => {
  const data = JSON.parse(event.data);
  console.log('New agent:', data);
});
```

#### List Tools
```http
GET /api/tools/list
```

Response:
```json
{
  "tools": [
    {
      "name": "swarm_init",
      "description": "Initialize a new swarm",
      "inputSchema": { ... }
    },
    // ... more tools
  ]
}
```

#### Execute Tool
```http
POST /api/tools/call
Content-Type: application/json

{
  "name": "swarm_init",
  "arguments": {
    "topology": "mesh",
    "maxAgents": 5
  }
}
```

Response:
```json
{
  "content": [{
    "type": "text",
    "text": "{ \"id\": \"swarm-123\", \"status\": \"initialized\" }"
  }]
}
```

#### Get Status
```http
GET /api/status
```

Response:
```json
{
  "agents": {
    "total": 5,
    "active": 3,
    "idle": 2
  },
  "tasks": {
    "total": 10,
    "pending": 2,
    "in_progress": 3,
    "completed": 5
  }
}
```

## Claude Flow Integration Examples

### 1. Basic Integration

```javascript
// claude-flow configuration
const ruvSwarmConfig = {
  endpoint: 'http://localhost:8080',
  sseEndpoint: 'http://localhost:8080/events',
  reconnectInterval: 5000
};

// Initialize connection
class RuvSwarmClient {
  constructor(config) {
    this.config = config;
    this.eventSource = null;
    this.connect();
  }

  connect() {
    this.eventSource = new EventSource(this.config.sseEndpoint);
    
    this.eventSource.onopen = () => {
      console.log('Connected to ruv-swarm');
    };
    
    this.eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      setTimeout(() => this.connect(), this.config.reconnectInterval);
    };
  }

  async callTool(name, args) {
    const response = await fetch(`${this.config.endpoint}/api/tools/call`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, arguments: args })
    });
    
    return response.json();
  }
}
```

### 2. Swarm Initialization

```javascript
const client = new RuvSwarmClient(ruvSwarmConfig);

// Initialize swarm
const swarmResult = await client.callTool('swarm_init', {
  topology: 'hierarchical',
  maxAgents: 10,
  strategy: 'adaptive'
});

// Spawn agents
const agents = await Promise.all([
  client.callTool('agent_spawn', { type: 'researcher', name: 'Data Analyzer' }),
  client.callTool('agent_spawn', { type: 'coder', name: 'API Developer' }),
  client.callTool('agent_spawn', { type: 'tester', name: 'QA Engineer' })
]);
```

### 3. Task Orchestration with Real-time Updates

```javascript
// Listen for task updates
client.eventSource.addEventListener('task:update', (event) => {
  const update = JSON.parse(event.data);
  updateUI(update);
});

// Orchestrate task
const task = await client.callTool('task_orchestrate', {
  task: 'Build REST API with authentication',
  strategy: 'parallel',
  priority: 'high'
});
```

## Environment Variables

```bash
# Enable claude-flow compatibility mode
export CLAUDE_FLOW_MODE=true

# Set HTTP server port
export CLAUDE_FLOW_PORT=8080

# Enable debug logging
export LOG_LEVEL=DEBUG
```

## Docker Deployment

```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 8080

# Run in HTTP daemon mode
CMD ["npx", "ruv-swarm", "mcp", "start", "--http", "--port", "8080"]
```

## Systemd Service

```ini
[Unit]
Description=ruv-swarm HTTP/SSE Server
After=network.target

[Service]
Type=simple
User=ruv-swarm
WorkingDirectory=/opt/ruv-swarm
ExecStart=/usr/bin/npx ruv-swarm mcp start --http --port 8080
Restart=always
RestartSec=10
Environment="NODE_ENV=production"
Environment="CLAUDE_FLOW_MODE=true"

[Install]
WantedBy=multi-user.target
```

## Security Considerations

1. **Authentication** - Add API key authentication for production
2. **CORS** - Configure allowed origins for production
3. **Rate Limiting** - Implement rate limiting for API endpoints
4. **SSL/TLS** - Use HTTPS in production environments
5. **Input Validation** - All inputs are validated and sanitized

## Troubleshooting

### Server won't start
- Check if port is already in use: `lsof -i :8080`
- Verify Node.js version: `node --version` (requires v18+)
- Check logs: `LOG_LEVEL=DEBUG npx ruv-swarm mcp start --http`

### SSE connection drops
- Check firewall/proxy settings
- Verify keep-alive is working
- Monitor network stability

### Tool execution fails
- Verify tool name and arguments
- Check server logs for errors
- Ensure WASM modules are loaded

## Migration from Stdio-only

If you're currently using the stdio-only version with claude-flow:

1. Update to latest version: `npm install ruv-swarm@latest`
2. Start with HTTP mode: `npx ruv-swarm mcp start --http`
3. Update claude-flow to use HTTP endpoints instead of stdio
4. Monitor SSE events for real-time updates

## Advanced Features

### Custom Event Handlers
```javascript
// Add custom event processing
client.eventSource.addEventListener('performance:metrics', (event) => {
  const metrics = JSON.parse(event.data);
  if (metrics.cpuUsage > 80) {
    // Scale down operations
  }
});
```

### Batch Operations
```javascript
// Execute multiple tools in parallel
const results = await Promise.all([
  client.callTool('swarm_init', { topology: 'mesh' }),
  client.callTool('agent_spawn', { type: 'researcher' }),
  client.callTool('agent_spawn', { type: 'coder' }),
  client.callTool('task_orchestrate', { task: 'Build API' })
]);
```

### Health Monitoring
```javascript
// Regular health checks
setInterval(async () => {
  try {
    const health = await fetch(`${config.endpoint}/health`).then(r => r.json());
    if (health.status !== 'ok') {
      console.warn('Server unhealthy:', health);
    }
  } catch (error) {
    console.error('Health check failed:', error);
  }
}, 30000);
```

## Conclusion

The hybrid architecture enables ruv-swarm to serve both Claude Code (via stdio) and claude-flow (via HTTP/SSE) simultaneously, providing maximum flexibility for different integration scenarios. The persistent HTTP server with SSE support ensures reliable, real-time communication for claude-flow while maintaining full compatibility with Claude Code's MCP protocol.