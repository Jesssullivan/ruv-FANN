#!/usr/bin/env node

const express = require('express');
const { Pool } = require('pg');
const Redis = require('ioredis');
const cors = require('cors');
const compression = require('compression');

// Import MCP tools and handlers
const { 
  initializeSwarm,
  spawnAgent,
  orchestrateTask,
  getSwarmStatus,
  neuralTrain,
  neuralPredict,
  memoryStore,
  memoryRetrieve
} = require('../ruv-swarm/npm/src/index.js');

const app = express();
const PORT = process.env.MCP_SERVER_PORT || 3000;

// Middleware
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '50mb' }));

// Database connections
const pgPool = new Pool({
  connectionString: process.env.POSTGRES_URL || 'postgresql://fann:fann123@localhost:5432/fanndb',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  lazyConnect: true,
});

// Hooks system
const hooks = {
  preTool: [],
  postTool: [],
  preSession: [],
  postSession: [],
};

// Register hook
app.post('/api/hooks/register', (req, res) => {
  const { type, handler } = req.body;
  if (hooks[type]) {
    hooks[type].push(handler);
    res.json({ success: true, message: `Hook registered for ${type}` });
  } else {
    res.status(400).json({ error: 'Invalid hook type' });
  }
});

// Execute hooks
async function executeHooks(type, data) {
  const results = [];
  for (const handler of hooks[type] || []) {
    try {
      const result = await handler(data);
      results.push(result);
    } catch (error) {
      console.error(`Hook execution error: ${error.message}`);
    }
  }
  return results;
}

// MCP Tools Registry API
app.get('/api/tools', (req, res) => {
  res.json({
    tools: [
      // Swarm Management
      { name: 'swarm_init', category: 'swarm', description: 'Initialize swarm with topology' },
      { name: 'agent_spawn', category: 'swarm', description: 'Spawn specialized agents' },
      { name: 'task_orchestrate', category: 'swarm', description: 'Orchestrate complex tasks' },
      { name: 'swarm_status', category: 'swarm', description: 'Get swarm status' },
      
      // Neural Operations
      { name: 'neural_train', category: 'neural', description: 'Train neural models' },
      { name: 'neural_predict', category: 'neural', description: 'Make predictions' },
      { name: 'neural_patterns', category: 'neural', description: 'Analyze cognitive patterns' },
      { name: 'neural_status', category: 'neural', description: 'Get neural network status' },
      
      // Memory Management
      { name: 'memory_store', category: 'memory', description: 'Store persistent memory' },
      { name: 'memory_retrieve', category: 'memory', description: 'Retrieve memory' },
      { name: 'memory_search', category: 'memory', description: 'Search memory patterns' },
      { name: 'memory_usage', category: 'memory', description: 'Get memory usage stats' },
      
      // DAA System
      { name: 'daa_agent_create', category: 'daa', description: 'Create autonomous agents' },
      { name: 'daa_workflow_create', category: 'daa', description: 'Create DAA workflows' },
      { name: 'daa_knowledge_share', category: 'daa', description: 'Share knowledge between agents' },
      { name: 'daa_consensus', category: 'daa', description: 'Achieve consensus' },
      
      // Performance
      { name: 'benchmark_run', category: 'performance', description: 'Run benchmarks' },
      { name: 'bottleneck_analyze', category: 'performance', description: 'Analyze bottlenecks' },
      { name: 'performance_report', category: 'performance', description: 'Generate reports' },
      { name: 'features_detect', category: 'performance', description: 'Detect features' },
      
      // GitHub Integration
      { name: 'github_repo_analyze', category: 'github', description: 'Analyze repositories' },
      { name: 'github_pr_manage', category: 'github', description: 'Manage pull requests' },
      { name: 'github_issue_track', category: 'github', description: 'Track issues' },
      { name: 'github_workflow_auto', category: 'github', description: 'Automate workflows' },
    ],
    version: '2.0.0',
    capabilities: {
      neural: true,
      daa: true,
      swarm: true,
      memory: true,
      github: true,
      simd: true,
      wasm: true,
    }
  });
});

// Tool discovery endpoint
app.get('/api/tools/:category', (req, res) => {
  const { category } = req.params;
  const tools = getToolsByCategory(category);
  res.json({ category, tools, count: tools.length });
});

// Tool execution with hooks
app.post('/api/tools/execute', async (req, res) => {
  const { tool, params } = req.body;
  
  try {
    // Pre-tool hook
    await executeHooks('preTool', { tool, params });
    
    // Execute tool
    const result = await executeToolByName(tool, params);
    
    // Post-tool hook
    await executeHooks('postTool', { tool, params, result });
    
    // Store in memory for persistence
    await redis.set(`tool:${tool}:${Date.now()}`, JSON.stringify({ params, result }));
    
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Session management
app.post('/api/session/start', async (req, res) => {
  const { sessionId, metadata } = req.body;
  
  try {
    await executeHooks('preSession', { sessionId, metadata });
    
    const session = {
      id: sessionId,
      startTime: new Date(),
      metadata,
      status: 'active',
    };
    
    await pgPool.query(
      'INSERT INTO sessions (id, data, status) VALUES ($1, $2, $3)',
      [sessionId, JSON.stringify(session), 'active']
    );
    
    res.json({ success: true, session });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/session/end', async (req, res) => {
  const { sessionId } = req.body;
  
  try {
    const result = await pgPool.query(
      'UPDATE sessions SET status = $1, end_time = $2 WHERE id = $3',
      ['completed', new Date(), sessionId]
    );
    
    await executeHooks('postSession', { sessionId });
    
    res.json({ success: true, updated: result.rowCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', async (req, res) => {
  try {
    await pgPool.query('SELECT 1');
    await redis.ping();
    res.json({ 
      status: 'healthy',
      services: {
        postgres: 'connected',
        redis: 'connected',
        mcp: 'running',
      }
    });
  } catch (error) {
    res.status(503).json({ 
      status: 'unhealthy',
      error: error.message 
    });
  }
});

// Claude Flow integration endpoint
app.post('/api/claude-flow/bootstrap', async (req, res) => {
  const { config } = req.body;
  
  try {
    // Initialize swarm
    const swarm = await initializeSwarm({
      topology: config.topology || 'hierarchical',
      maxAgents: config.maxAgents || 8,
    });
    
    // Store configuration
    await redis.set('claude-flow:config', JSON.stringify(config));
    await redis.set('claude-flow:swarm', JSON.stringify(swarm));
    
    res.json({
      success: true,
      swarmId: swarm.id,
      message: 'Claude Flow integration bootstrapped',
      endpoints: {
        tools: '/api/tools',
        execute: '/api/tools/execute',
        session: '/api/session',
        hooks: '/api/hooks',
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Helper functions
function getToolsByCategory(category) {
  const allTools = {
    swarm: ['swarm_init', 'agent_spawn', 'task_orchestrate', 'swarm_status'],
    neural: ['neural_train', 'neural_predict', 'neural_patterns', 'neural_status'],
    memory: ['memory_store', 'memory_retrieve', 'memory_search', 'memory_usage'],
    daa: ['daa_agent_create', 'daa_workflow_create', 'daa_knowledge_share', 'daa_consensus'],
    performance: ['benchmark_run', 'bottleneck_analyze', 'performance_report', 'features_detect'],
    github: ['github_repo_analyze', 'github_pr_manage', 'github_issue_track', 'github_workflow_auto'],
  };
  return allTools[category] || [];
}

async function executeToolByName(toolName, params) {
  const toolMap = {
    swarm_init: initializeSwarm,
    agent_spawn: spawnAgent,
    task_orchestrate: orchestrateTask,
    swarm_status: getSwarmStatus,
    neural_train: neuralTrain,
    neural_predict: neuralPredict,
    memory_store: memoryStore,
    memory_retrieve: memoryRetrieve,
    // Add more tool mappings as needed
  };
  
  const tool = toolMap[toolName];
  if (!tool) {
    throw new Error(`Unknown tool: ${toolName}`);
  }
  
  return await tool(params);
}

// Initialize database tables
async function initDatabase() {
  try {
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS sessions (
        id VARCHAR(255) PRIMARY KEY,
        data JSONB,
        status VARCHAR(50),
        start_time TIMESTAMP DEFAULT NOW(),
        end_time TIMESTAMP
      )
    `);
    
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS tool_executions (
        id SERIAL PRIMARY KEY,
        session_id VARCHAR(255),
        tool_name VARCHAR(255),
        params JSONB,
        result JSONB,
        executed_at TIMESTAMP DEFAULT NOW()
      )
    `);
    
    console.log('Database initialized');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Start server
async function start() {
  await initDatabase();
  await redis.connect();
  
  app.listen(PORT, () => {
    console.log(`MCP Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Tools API: http://localhost:${PORT}/api/tools`);
  });
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down gracefully...');
  await pgPool.end();
  await redis.quit();
  process.exit(0);
});

start().catch(console.error);