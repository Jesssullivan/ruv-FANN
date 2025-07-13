#!/usr/bin/env node
/**
 * Hybrid ruv-swarm MCP server with stdio AND HTTP/SSE support
 * Supports both Claude Code (stdio) and claude-flow (HTTP/SSE) integration
 */

import { spawn } from 'child_process';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import http from 'http';
import { EventEmitter } from 'events';

// Lazy imports - only load when needed
let RuvSwarm, EnhancedMCPTools, daaMcpTools, Logger, CommandSanitizer, SecurityError;
let setupClaudeIntegration, invokeClaudeWithSwarm;

// Global event emitter for SSE
const sseEventEmitter = new EventEmitter();
const sseClients = new Map();

async function loadDependencies() {
    if (!RuvSwarm) {
        const [indexEnhanced, mcpToolsEnhanced, mcpDaaTools, logger, security, claudeIntegration] = await Promise.all([
            import('../src/index-enhanced.js'),
            import('../src/mcp-tools-enhanced.js'),
            import('../src/mcp-daa-tools.js'),
            import('../src/logger.js'),
            import('../src/security.js'),
            import('../src/claude-integration/index.js')
        ]);
        
        RuvSwarm = indexEnhanced.RuvSwarm;
        EnhancedMCPTools = mcpToolsEnhanced.EnhancedMCPTools;
        daaMcpTools = mcpDaaTools.daaMcpTools;
        Logger = logger.Logger;
        CommandSanitizer = security.CommandSanitizer;
        SecurityError = security.SecurityError;
        setupClaudeIntegration = claudeIntegration.setupClaudeIntegration;
        invokeClaudeWithSwarm = claudeIntegration.invokeClaudeWithSwarm;
    }
}

// Get version from package.json
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function getVersion() {
    try {
        const packagePath = join(__dirname, '..', 'package.json');
        const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));
        return packageJson.version;
    } catch (error) {
        return 'unknown';
    }
}

// Global instances
let globalRuvSwarm = null;
let globalMCPTools = null;
let globalLogger = null;
let httpServer = null;

// Initialize logger based on environment
async function initializeLogger() {
    if (!globalLogger) {
        await loadDependencies();
        globalLogger = new Logger({
            name: 'ruv-swarm-hybrid',
            level: process.env.LOG_LEVEL || (process.argv.includes('--debug') ? 'DEBUG' : 'INFO'),
            enableStderr: true,
            enableFile: process.env.LOG_TO_FILE === 'true',
            formatJson: process.env.LOG_FORMAT === 'json',
            logDir: process.env.LOG_DIR || './logs',
            metadata: {
                pid: process.pid,
                version: await getVersion(),
                mode: 'hybrid-mcp'
            }
        });
        
        // Set up global error handlers
        process.on('uncaughtException', (error) => {
            if (globalLogger && typeof globalLogger.fatal === 'function') {
                globalLogger.fatal('Uncaught exception', { error });
            } else {
                console.error('❌ Uncaught Exception:', error.message);
            }
            process.exit(1);
        });
        
        process.on('unhandledRejection', (reason, promise) => {
            if (globalLogger && typeof globalLogger.fatal === 'function') {
                globalLogger.fatal('Unhandled rejection', { reason, promise });
            } else {
                console.error('❌ Unhandled Rejection:', reason);
            }
            process.exit(1);
        });
    }
    return globalLogger;
}

async function initializeSystem() {
    await loadDependencies();
    
    if (!globalRuvSwarm) {
        globalRuvSwarm = await RuvSwarm.initialize({
            loadingStrategy: 'progressive',
            enablePersistence: true,
            enableNeuralNetworks: true,
            enableForecasting: true,
            useSIMD: RuvSwarm.detectSIMDSupport(),
            debug: process.argv.includes('--debug')
        });
    }
    
    if (!globalMCPTools) {
        globalMCPTools = new EnhancedMCPTools(globalRuvSwarm);
        await globalMCPTools.initialize(globalRuvSwarm);
        
        // Initialize DAA MCP tools with the same instance
        daaMcpTools.mcpTools = globalMCPTools;
        await daaMcpTools.ensureInitialized();
        
        // Add DAA tool methods to the MCP tools object
        const daaToolNames = [
            'daa_init', 'daa_agent_create', 'daa_agent_adapt', 'daa_workflow_create',
            'daa_workflow_execute', 'daa_knowledge_share', 'daa_learning_status',
            'daa_cognitive_pattern', 'daa_meta_learning', 'daa_performance_metrics'
        ];
        
        for (const toolName of daaToolNames) {
            if (typeof daaMcpTools[toolName] === 'function') {
                globalMCPTools[toolName] = daaMcpTools[toolName].bind(daaMcpTools);
            }
        }
    }
    
    return { ruvSwarm: globalRuvSwarm, mcpTools: globalMCPTools };
}

// HTTP/SSE Server Implementation
async function startHttpServer(port = 8080) {
    const logger = await initializeLogger();
    logger.info('Starting HTTP/SSE server for claude-flow integration', { port });
    
    httpServer = http.createServer(async (req, res) => {
        const { pathname } = new URL(req.url, `http://${req.headers.host}`);
        
        // Enable CORS
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
        
        if (req.method === 'OPTIONS') {
            res.writeHead(200);
            res.end();
            return;
        }
        
        switch (pathname) {
            case '/health':
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ 
                    status: 'ok', 
                    version: await getVersion(),
                    mode: 'hybrid',
                    timestamp: new Date().toISOString()
                }));
                break;
                
            case '/events':
                // SSE endpoint for real-time updates
                const clientId = Date.now().toString();
                logger.info('SSE client connected', { clientId });
                
                res.writeHead(200, {
                    'Content-Type': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive'
                });
                
                // Send initial connection event
                res.write(`event: connected\ndata: ${JSON.stringify({ clientId, timestamp: new Date().toISOString() })}\n\n`);
                
                // Store client
                sseClients.set(clientId, res);
                
                // Send heartbeat every 30 seconds
                const heartbeat = setInterval(() => {
                    res.write(':heartbeat\n\n');
                }, 30000);
                
                // Register event listeners
                const sendEvent = (eventType, data) => {
                    const message = `event: ${eventType}\ndata: ${JSON.stringify(data)}\n\n`;
                    res.write(message);
                };
                
                sseEventEmitter.on('swarm:update', data => sendEvent('swarm:update', data));
                sseEventEmitter.on('agent:spawn', data => sendEvent('agent:spawn', data));
                sseEventEmitter.on('task:update', data => sendEvent('task:update', data));
                sseEventEmitter.on('performance:metrics', data => sendEvent('performance:metrics', data));
                
                // Clean up on disconnect
                req.on('close', () => {
                    clearInterval(heartbeat);
                    sseClients.delete(clientId);
                    sseEventEmitter.removeAllListeners();
                    logger.info('SSE client disconnected', { clientId });
                });
                break;
                
            case '/api/tools/list':
                if (req.method !== 'GET') {
                    res.writeHead(405);
                    res.end();
                    return;
                }
                
                const { mcpTools } = await initializeSystem();
                const tools = await handleMcpRequest({ method: 'tools/list' }, mcpTools, logger);
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(tools.result || { error: tools.error }));
                break;
                
            case '/api/tools/call':
                if (req.method !== 'POST') {
                    res.writeHead(405);
                    res.end();
                    return;
                }
                
                let body = '';
                req.on('data', chunk => body += chunk);
                req.on('end', async () => {
                    try {
                        const { name, arguments: args } = JSON.parse(body);
                        const { mcpTools } = await initializeSystem();
                        
                        const result = await handleMcpRequest({
                            method: 'tools/call',
                            params: { name, arguments: args }
                        }, mcpTools, logger);
                        
                        // Emit SSE event for tool execution
                        sseEventEmitter.emit('tool:executed', {
                            tool: name,
                            timestamp: new Date().toISOString(),
                            success: !result.error
                        });
                        
                        res.writeHead(200, { 'Content-Type': 'application/json' });
                        res.end(JSON.stringify(result.result || { error: result.error }));
                    } catch (error) {
                        res.writeHead(400, { 'Content-Type': 'application/json' });
                        res.end(JSON.stringify({ error: error.message }));
                    }
                });
                break;
                
            case '/api/status':
                const { mcpTools: statusTools } = await initializeSystem();
                const status = await statusTools.swarm_status({ verbose: true });
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(status));
                break;
                
            default:
                res.writeHead(404);
                res.end('Not Found');
        }
    });
    
    httpServer.listen(port, () => {
        logger.info(`HTTP/SSE server listening on port ${port}`);
        console.log(`🌐 HTTP/SSE server running at http://localhost:${port}`);
        console.log(`📡 SSE endpoint: http://localhost:${port}/events`);
        console.log(`🔧 API endpoints:`);
        console.log(`   GET  /health - Health check`);
        console.log(`   GET  /api/tools/list - List available tools`);
        console.log(`   POST /api/tools/call - Execute a tool`);
        console.log(`   GET  /api/status - Get swarm status`);
    });
    
    return httpServer;
}

// Stdio MCP Server (for Claude Code)
async function startStdioServer() {
    const logger = await initializeLogger();
    const sessionId = logger.setCorrelationId();
    
    logger.info('ruv-swarm hybrid MCP server starting in stdio mode', {
        sessionId,
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch
    });
    
    // Initialize system
    const { ruvSwarm, mcpTools } = await initializeSystem();
    
    // Start stdio MCP server loop
    process.stdin.setEncoding('utf8');
    
    let buffer = '';
    let messageCount = 0;
    
    process.stdin.on('data', async (chunk) => {
        logger.trace('Received stdin data', { bytes: chunk.length });
        buffer += chunk;
        
        // Process complete JSON messages
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        
        for (const line of lines) {
            if (line.trim()) {
                messageCount++;
                const messageId = `msg-${sessionId}-${messageCount}`;
                
                try {
                    const request = JSON.parse(line);
                    logger.logMcp('in', request.method || 'unknown', {
                        method: request.method,
                        id: request.id,
                        params: request.params,
                        messageId
                    });
                    
                    const response = await handleMcpRequest(request, mcpTools, logger);
                    
                    logger.logMcp('out', request.method || 'response', {
                        method: request.method,
                        id: response.id,
                        result: response.result,
                        error: response.error,
                        messageId
                    });
                    
                    process.stdout.write(JSON.stringify(response) + '\n');
                } catch (error) {
                    logger.error('JSON parse error', { error, line: line.substring(0, 100), messageId });
                    
                    const errorResponse = {
                        jsonrpc: '2.0',
                        error: {
                            code: -32700,
                            message: 'Parse error',
                            data: error.message
                        },
                        id: null
                    };
                    process.stdout.write(JSON.stringify(errorResponse) + '\n');
                }
            }
        }
    });
    
    // Handle stdin close
    process.stdin.on('end', () => {
        logger.logConnection('closed', sessionId, {
            messagesProcessed: messageCount,
            uptime: process.uptime()
        });
        logger.info('MCP: stdin closed, shutting down...');
        process.exit(0);
    });
    
    // Send initialization message
    const version = await getVersion();
    const initMessage = {
        jsonrpc: '2.0',
        method: 'server.initialized',
        params: {
            serverInfo: {
                name: 'ruv-swarm-hybrid',
                version: version,
                capabilities: {
                    tools: true,
                    prompts: false,
                    resources: true
                }
            }
        }
    };
    process.stdout.write(JSON.stringify(initMessage) + '\n');
}

// Shared MCP request handler
async function handleMcpRequest(request, mcpTools, logger) {
    const response = {
        jsonrpc: '2.0',
        id: request.id
    };
    
    try {
        switch (request.method) {
            case 'initialize':
                const version = await getVersion();
                response.result = {
                    protocolVersion: '2024-11-05',
                    capabilities: {
                        tools: {},
                        resources: {
                            list: true,
                            read: true
                        }
                    },
                    serverInfo: {
                        name: 'ruv-swarm-hybrid',
                        version: version
                    }
                };
                break;
                
            case 'tools/list':
                response.result = {
                    tools: [
                        // Core tools
                        {
                            name: 'swarm_init',
                            description: 'Initialize a new swarm with specified topology',
                            inputSchema: {
                                type: 'object',
                                properties: {
                                    topology: { type: 'string', enum: ['mesh', 'hierarchical', 'ring', 'star'] },
                                    maxAgents: { type: 'number', minimum: 1, maximum: 100, default: 5 },
                                    strategy: { type: 'string', enum: ['balanced', 'specialized', 'adaptive'], default: 'balanced' }
                                },
                                required: ['topology']
                            }
                        },
                        // Add other tools...
                        ...(await getToolDefinitions())
                    ]
                };
                break;
                
            case 'tools/call':
                const toolName = request.params.name;
                const toolArgs = request.params.arguments || {};
                
                let result = null;
                
                // Try regular MCP tools first
                if (mcpTools && typeof mcpTools[toolName] === 'function') {
                    result = await mcpTools[toolName](toolArgs);
                }
                // Try DAA tools if not found
                else if (typeof daaMcpTools[toolName] === 'function') {
                    result = await daaMcpTools[toolName](toolArgs);
                }
                
                if (result !== null) {
                    // Emit SSE event for HTTP clients
                    if (sseClients.size > 0) {
                        sseEventEmitter.emit('tool:executed', {
                            tool: toolName,
                            args: toolArgs,
                            timestamp: new Date().toISOString()
                        });
                    }
                    
                    response.result = {
                        content: [{
                            type: 'text',
                            text: typeof result === 'string' ? result : JSON.stringify(result, null, 2)
                        }]
                    };
                } else {
                    response.error = {
                        code: -32601,
                        message: 'Method not found',
                        data: `Unknown tool: ${toolName}`
                    };
                }
                break;
                
            default:
                response.error = {
                    code: -32601,
                    message: 'Method not found',
                    data: `Unknown method: ${request.method}`
                };
        }
    } catch (error) {
        response.error = {
            code: -32603,
            message: 'Internal error',
            data: error.message
        };
    }
    
    return response;
}

// Get all tool definitions
async function getToolDefinitions() {
    // This would return all tool definitions
    // Simplified for brevity
    return [];
}

// Main entry point
async function main() {
    const args = process.argv.slice(2);
    
    if (args.includes('--help') || args.includes('-h')) {
        console.log(`
🐝 ruv-swarm Hybrid Server - Supports both stdio (Claude Code) and HTTP/SSE (claude-flow)

Usage: ruv-swarm-hybrid [options]

Options:
  --stdio              Run in stdio mode only (default)
  --http               Run in HTTP/SSE mode only
  --hybrid             Run both stdio and HTTP/SSE servers
  --port <port>        HTTP server port (default: 8080)
  --daemon             Run as background daemon
  --keep-alive         Keep process alive for claude-flow
  --debug              Enable debug logging

Examples:
  # For Claude Code (stdio)
  ruv-swarm-hybrid --stdio
  
  # For claude-flow (HTTP/SSE)
  ruv-swarm-hybrid --http --port 8080
  
  # For both (hybrid mode)
  ruv-swarm-hybrid --hybrid
  
  # As a daemon
  ruv-swarm-hybrid --http --daemon

Environment Variables:
  CLAUDE_FLOW_MODE=true    Enable claude-flow compatibility
  CLAUDE_FLOW_PORT=8080    HTTP server port
`);
        process.exit(0);
    }
    
    const mode = args.includes('--hybrid') ? 'hybrid' :
                 args.includes('--http') ? 'http' :
                 'stdio';
                 
    const port = parseInt(args[args.indexOf('--port') + 1]) || 
                 process.env.CLAUDE_FLOW_PORT || 
                 8080;
    
    const isDaemon = args.includes('--daemon');
    const keepAlive = args.includes('--keep-alive') || process.env.CLAUDE_FLOW_MODE === 'true';
    
    try {
        if (mode === 'stdio' || mode === 'hybrid') {
            await startStdioServer();
        }
        
        if (mode === 'http' || mode === 'hybrid') {
            await startHttpServer(port);
        }
        
        // Keep process alive if needed
        if (keepAlive || isDaemon || mode === 'http' || mode === 'hybrid') {
            console.log('🔄 Running in persistent mode for claude-flow compatibility');
            
            // Prevent process from exiting
            setInterval(() => {}, 1000 * 60 * 60); // Keep alive
        }
        
    } catch (error) {
        console.error('❌ Failed to start server:', error.message);
        process.exit(1);
    }
}

// Handle process termination
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    if (httpServer) {
        httpServer.close();
    }
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully...');
    if (httpServer) {
        httpServer.close();
    }
    process.exit(0);
});

// Run main
main();