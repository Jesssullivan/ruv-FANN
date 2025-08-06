# MCP Tools Registry API Design

## Overview

The MCP Tools Registry API provides comprehensive discovery, introspection, and management capabilities for all MCP tools in the FANN ecosystem. This API serves as the central hub for tool discovery, performance metrics, usage analytics, and intelligent recommendations.

## API Specifications

### Base URL
```
Production: https://api.fann.ai/v2
Development: http://localhost:3000/api/v2
```

### Authentication
```http
Authorization: Bearer <api-key>
X-Session-ID: <session-identifier>
X-Client-Version: <client-version>
```

## Core Endpoints

### 1. Tool Discovery

#### List All Tools
```http
GET /tools
```

**Query Parameters:**
- `category` (string): Filter by tool category
- `capability` (array): Filter by capabilities
- `complexity` (enum): simple, medium, complex
- `performance` (enum): low, medium, high
- `stability` (enum): experimental, beta, stable, deprecated
- `limit` (integer): Results per page (default: 50, max: 100)
- `offset` (integer): Pagination offset (default: 0)
- `sort` (enum): name, category, performance, usage (default: name)
- `order` (enum): asc, desc (default: asc)

**Response:**
```json
{
  "tools": [
    {
      "name": "swarm_init",
      "version": "2.0.0",
      "category": "swarm",
      "description": "Initialize swarm with topology and configuration",
      "complexity": "medium",
      "stability": "stable",
      "capabilities": ["distributed_processing", "auto_scaling"],
      "performance": {
        "averageLatency": "45ms",
        "throughput": "2000/s",
        "successRate": 0.995,
        "resourceUsage": "medium"
      },
      "usage": {
        "totalExecutions": 15420,
        "last24h": 342,
        "averageRating": 4.6
      },
      "metadata": {
        "author": "FANN Team",
        "tags": ["coordination", "distributed"],
        "lastUpdated": "2025-01-15T10:30:00Z"
      }
    }
  ],
  "pagination": {
    "total": 27,
    "limit": 50,
    "offset": 0,
    "hasMore": false,
    "pages": {
      "current": 1,
      "total": 1,
      "next": null,
      "prev": null
    }
  },
  "metadata": {
    "categories": ["swarm", "neural", "memory", "daa", "performance", "github"],
    "capabilities": [
      "distributed_processing",
      "neural_learning", 
      "persistent_memory",
      "real_time_monitoring"
    ],
    "complexityDistribution": {
      "simple": 8,
      "medium": 12,
      "complex": 7
    },
    "stabilityDistribution": {
      "stable": 22,
      "beta": 4,
      "experimental": 1
    }
  }
}
```

#### Get Specific Tool
```http
GET /tools/{name}
```

**Path Parameters:**
- `name` (string, required): Tool name

**Response:**
```json
{
  "name": "swarm_init",
  "version": "2.0.0",
  "category": "swarm",
  "description": "Initialize swarm with topology and configuration",
  "longDescription": "Creates and configures a new swarm instance with specified topology, maximum agent count, and coordination strategy. Supports multiple topologies including mesh, hierarchical, ring, and star configurations.",
  "schema": {
    "type": "object",
    "required": ["topology"],
    "properties": {
      "topology": {
        "type": "string",
        "enum": ["mesh", "hierarchical", "ring", "star"],
        "description": "Network topology for agent communication"
      },
      "maxAgents": {
        "type": "number",
        "minimum": 1,
        "maximum": 100,
        "default": 8,
        "description": "Maximum number of agents in the swarm"
      },
      "strategy": {
        "type": "string",
        "enum": ["adaptive", "balanced", "specialized"],
        "default": "balanced",
        "description": "Agent coordination strategy"
      }
    }
  },
  "performance": {
    "averageLatency": "45ms",
    "p50": "35ms",
    "p90": "65ms", 
    "p95": "85ms",
    "p99": "120ms",
    "throughput": "2000/s",
    "successRate": 0.995,
    "resourceUsage": "medium",
    "scalability": "linear",
    "memoryFootprint": "15MB",
    "cpuUsage": "12%"
  },
  "dependencies": [
    {
      "name": "neural_engine",
      "version": ">=2.0.0",
      "required": true,
      "type": "service"
    },
    {
      "name": "persistence_layer", 
      "version": ">=1.5.0",
      "required": true,
      "type": "service"
    }
  ],
  "capabilities": [
    "distributed_processing",
    "auto_scaling",
    "conflict_resolution",
    "real_time_monitoring"
  ],
  "hooks": {
    "pre": ["validation", "resource_check", "topology_optimization"],
    "post": ["metrics_collection", "pattern_learning", "state_persistence"]
  },
  "examples": [
    {
      "name": "Basic mesh swarm",
      "description": "Create a basic mesh topology swarm for general tasks",
      "complexity": "simple",
      "params": {
        "topology": "mesh",
        "maxAgents": 5
      },
      "expectedResult": {
        "swarmId": "swarm_1735123456789",
        "status": "initialized",
        "agents": 0,
        "topology": "mesh"
      }
    },
    {
      "name": "Hierarchical swarm for complex tasks",
      "description": "Set up hierarchical topology for complex, structured tasks",
      "complexity": "medium",
      "params": {
        "topology": "hierarchical",
        "maxAgents": 12,
        "strategy": "specialized"
      },
      "expectedResult": {
        "swarmId": "swarm_1735123456790",
        "status": "initialized", 
        "agents": 0,
        "topology": "hierarchical",
        "coordinatorAgent": "coordinator_001"
      }
    }
  ],
  "usage": {
    "totalExecutions": 15420,
    "successfulExecutions": 15343,
    "failedExecutions": 77,
    "last24h": 342,
    "last7d": 2108,
    "last30d": 8765,
    "averageRating": 4.6,
    "totalFeedback": 256
  },
  "relatedTools": [
    {
      "name": "agent_spawn",
      "relationship": "commonly_used_after",
      "confidence": 0.92
    },
    {
      "name": "swarm_status", 
      "relationship": "monitoring",
      "confidence": 0.85
    }
  ],
  "metadata": {
    "author": "FANN Team",
    "maintainer": "dev-team@fann.ai",
    "repository": "https://github.com/ruvnet/ruv-FANN",
    "documentation": "https://docs.fann.ai/tools/swarm_init",
    "license": "MIT",
    "tags": ["coordination", "distributed", "initialization"],
    "stability": "stable",
    "createdAt": "2024-08-01T00:00:00Z",
    "lastUpdated": "2025-01-15T10:30:00Z",
    "changeHistory": [
      {
        "version": "2.0.0",
        "date": "2025-01-15T10:30:00Z",
        "changes": ["Added adaptive strategy", "Improved error handling"]
      }
    ]
  }
}
```

### 2. Tool Search and Discovery

#### Advanced Search
```http
GET /tools/search
```

**Query Parameters:**
- `q` (string, required): Search query
- `category` (string): Filter by category
- `fuzzy` (boolean): Enable fuzzy matching (default: true)
- `limit` (integer): Results limit (default: 20, max: 50)
- `include_score` (boolean): Include relevance scores (default: false)

**Response:**
```json
{
  "query": "neural training optimization",
  "results": [
    {
      "name": "neural_train",
      "category": "neural",
      "description": "Train neural network models with WASM SIMD acceleration",
      "score": 0.95,
      "matchedFields": ["description", "capabilities", "tags"],
      "highlights": {
        "description": "<mark>Neural</mark> network <mark>training</mark> with advanced <mark>optimization</mark>"
      }
    }
  ],
  "metadata": {
    "totalMatches": 5,
    "searchTime": "12ms",
    "suggestions": [
      "neural_patterns",
      "performance_optimization", 
      "training_optimization"
    ],
    "filters": {
      "categories": {
        "neural": 3,
        "performance": 2
      },
      "capabilities": {
        "neural_learning": 4,
        "performance_optimization": 3
      }
    }
  }
}
```

#### Semantic Search
```http
POST /tools/semantic-search
```

**Request Body:**
```json
{
  "query": "I need to coordinate multiple AI agents to work on a complex software development task",
  "context": {
    "domain": "software_development",
    "complexity": "high",
    "teamSize": "medium"
  },
  "preferences": {
    "performance": "high",
    "reliability": "high",
    "learningCapability": "required"
  }
}
```

**Response:**
```json
{
  "results": [
    {
      "name": "swarm_init",
      "relevance": 0.92,
      "reasoning": "Essential for coordinating multiple agents in complex tasks",
      "category": "swarm"
    },
    {
      "name": "task_orchestrate",
      "relevance": 0.88,
      "reasoning": "Manages complex task distribution across agent network",
      "category": "swarm"
    },
    {
      "name": "daa_agent_create",
      "relevance": 0.85,
      "reasoning": "Creates autonomous agents with learning capabilities",
      "category": "daa"
    }
  ],
  "suggestedWorkflow": {
    "steps": [
      {
        "order": 1,
        "tool": "swarm_init",
        "purpose": "Initialize coordination infrastructure"
      },
      {
        "order": 2,
        "tool": "daa_agent_create",
        "purpose": "Create specialized agents for different aspects"
      },
      {
        "order": 3, 
        "tool": "task_orchestrate",
        "purpose": "Distribute and coordinate the complex task"
      }
    ],
    "estimatedDuration": "15-30 minutes",
    "complexity": "medium-high"
  }
}
```

### 3. Tool Introspection

#### Get Tool Schema
```http
GET /tools/{name}/schema
```

**Response:**
```json
{
  "name": "swarm_init",
  "schema": {
    "type": "object",
    "title": "Swarm Initialization Parameters",
    "description": "Parameters for initializing a new swarm instance",
    "required": ["topology"],
    "properties": {
      "topology": {
        "type": "string",
        "enum": ["mesh", "hierarchical", "ring", "star"],
        "description": "Network topology for agent communication",
        "examples": ["mesh", "hierarchical"],
        "default": "mesh"
      }
    }
  },
  "validation": {
    "strict": true,
    "additionalProperties": false,
    "errorMessages": {
      "topology": "Topology must be one of: mesh, hierarchical, ring, star"
    }
  },
  "optimization": {
    "recommendedDefaults": {
      "topology": "mesh",
      "maxAgents": 8,
      "strategy": "balanced"
    },
    "performanceHints": {
      "mesh": "Best for collaborative tasks requiring peer communication",
      "hierarchical": "Optimal for structured tasks with clear delegation"
    }
  }
}
```

#### Get Tool Performance Metrics
```http
GET /tools/{name}/performance
```

**Query Parameters:**
- `timeframe` (string): 1h, 24h, 7d, 30d (default: 24h)
- `breakdown` (boolean): Include detailed breakdown (default: false)

**Response:**
```json
{
  "tool": "swarm_init",
  "timeframe": "24h",
  "current": {
    "averageLatency": 45.2,
    "successRate": 0.995,
    "throughput": 1850,
    "errorRate": 0.005,
    "resourceUtilization": {
      "cpu": 0.12,
      "memory": 15.6,
      "network": 2.1
    }
  },
  "trend": {
    "latency": {
      "change": -2.1,
      "direction": "improving"
    },
    "successRate": {
      "change": 0.001,
      "direction": "stable"
    },
    "throughput": {
      "change": 150,
      "direction": "improving"
    }
  },
  "percentiles": {
    "p50": 35.0,
    "p75": 52.0,
    "p90": 65.0,
    "p95": 85.0,
    "p99": 120.0
  },
  "breakdown": {
    "byTopology": {
      "mesh": {
        "avgLatency": 42.1,
        "successRate": 0.996
      },
      "hierarchical": {
        "avgLatency": 48.3,
        "successRate": 0.994
      }
    },
    "byAgentCount": {
      "1-5": { "avgLatency": 38.2, "successRate": 0.998 },
      "6-10": { "avgLatency": 45.1, "successRate": 0.995 },
      "11-20": { "avgLatency": 52.8, "successRate": 0.992 }
    }
  },
  "alerts": [
    {
      "type": "performance_degradation",
      "severity": "low",
      "message": "Latency increased by 5% for hierarchical topology",
      "timestamp": "2025-01-15T14:30:00Z"
    }
  ]
}
```

### 4. Tool Recommendations

#### Get Personalized Recommendations
```http
POST /tools/recommend
```

**Request Body:**
```json
{
  "context": "Building a real-time data processing pipeline with ML inference",
  "currentTools": ["swarm_init", "neural_train"],
  "preferences": {
    "performance": "high",
    "complexity": "medium",
    "reliability": "high",
    "scalability": "required"
  },
  "constraints": {
    "maxTools": 5,
    "excludeTools": ["deprecated_tool"],
    "requireCapabilities": ["real_time_monitoring", "auto_scaling"]
  },
  "userProfile": {
    "experienceLevel": "intermediate",
    "domains": ["data_processing", "machine_learning"],
    "previousSuccess": ["swarm_init", "task_orchestrate"]
  }
}
```

**Response:**
```json
{
  "recommendations": [
    {
      "name": "task_orchestrate",
      "confidence": 0.92,
      "category": "swarm",
      "reasoning": "Perfect for coordinating data processing tasks across multiple agents",
      "expectedBenefit": "40-60% improvement in processing throughput",
      "integrationComplexity": "low",
      "estimatedTime": "10-15 minutes",
      "prerequisites": ["swarm_init"],
      "synergy": {
        "with": ["neural_train"],
        "benefit": "Enables distributed ML model training"
      }
    },
    {
      "name": "memory_usage",
      "confidence": 0.85,
      "category": "memory",
      "reasoning": "Essential for persistent state in real-time pipelines",
      "expectedBenefit": "Eliminate data loss during processing",
      "integrationComplexity": "medium",
      "estimatedTime": "20-30 minutes"
    }
  ],
  "workflow": {
    "name": "Real-time ML Pipeline",
    "description": "Complete workflow for real-time data processing with ML inference",
    "steps": [
      {
        "order": 1,
        "tool": "swarm_init",
        "params": { "topology": "mesh", "maxAgents": 6 },
        "purpose": "Initialize processing infrastructure"
      },
      {
        "order": 2,
        "tool": "memory_usage",
        "params": { "action": "store", "namespace": "pipeline" },
        "purpose": "Setup persistent state management"
      },
      {
        "order": 3,
        "tool": "task_orchestrate",
        "params": { "strategy": "adaptive", "priority": "high" },
        "purpose": "Coordinate real-time processing tasks"
      }
    ],
    "estimatedDuration": "45-60 minutes",
    "complexity": "medium-high",
    "successProbability": 0.88
  },
  "alternatives": [
    {
      "name": "Single-agent approach",
      "tools": ["neural_predict"],
      "tradeoffs": "Lower complexity but reduced throughput",
      "whenToUse": "For simpler, lower-volume processing"
    }
  ],
  "metadata": {
    "totalConsideredTools": 27,
    "averageConfidence": 0.89,
    "analysisTime": "150ms",
    "personalizationFactors": [
      "user_experience_level",
      "domain_expertise", 
      "previous_tool_success"
    ]
  }
}
```

#### Get Tool Compatibility Matrix
```http
GET /tools/compatibility
```

**Query Parameters:**
- `tool` (string): Base tool name
- `depth` (integer): Relationship depth (default: 2, max: 3)

**Response:**
```json
{
  "baseTool": "swarm_init",
  "compatibility": {
    "highSynergy": [
      {
        "name": "agent_spawn",
        "synergy": 0.95,
        "relationship": "sequential",
        "benefits": ["Natural workflow progression", "Shared swarm context"]
      },
      {
        "name": "task_orchestrate", 
        "synergy": 0.91,
        "relationship": "complementary",
        "benefits": ["Utilizes initialized swarm", "Enhanced coordination"]
      }
    ],
    "moderate": [
      {
        "name": "neural_train",
        "synergy": 0.72,
        "relationship": "parallel",
        "benefits": ["Can leverage swarm for distributed training"]
      }
    ],
    "conflicts": [
      {
        "name": "deprecated_swarm_v1",
        "conflict": 0.85,
        "reason": "Version compatibility issues",
        "resolution": "Use swarm_init v2.0+ instead"
      }
    ]
  },
  "workflows": [
    {
      "name": "Basic Swarm Setup",
      "tools": ["swarm_init", "agent_spawn", "swarm_status"],
      "popularity": 0.78,
      "successRate": 0.94
    }
  ]
}
```

### 5. Tool Categories and Capabilities

#### List Categories
```http
GET /categories
```

**Response:**
```json
{
  "categories": [
    {
      "name": "swarm",
      "displayName": "Swarm Management",
      "description": "Tools for creating and managing agent swarms",
      "toolCount": 8,
      "subcategories": ["initialization", "monitoring", "scaling"],
      "complexity": "medium",
      "maturityLevel": "stable"
    },
    {
      "name": "neural",
      "displayName": "Neural Networks", 
      "description": "Machine learning and neural network operations",
      "toolCount": 6,
      "subcategories": ["training", "inference", "optimization"],
      "complexity": "high",
      "maturityLevel": "stable"
    }
  ],
  "metadata": {
    "totalCategories": 6,
    "totalTools": 27,
    "averageToolsPerCategory": 4.5
  }
}
```

#### List Capabilities
```http
GET /capabilities
```

**Response:**
```json
{
  "capabilities": [
    {
      "name": "distributed_processing",
      "description": "Ability to distribute work across multiple agents",
      "toolCount": 12,
      "complexity": "high",
      "prerequisites": ["swarm_infrastructure"],
      "benefits": [
        "Improved performance through parallelization",
        "Better resource utilization",
        "Fault tolerance through redundancy"
      ]
    },
    {
      "name": "neural_learning",
      "description": "Machine learning and pattern recognition capabilities",
      "toolCount": 8,
      "complexity": "high",
      "prerequisites": ["neural_engine"],
      "benefits": [
        "Adaptive behavior improvement",
        "Pattern recognition",
        "Predictive optimization"
      ]
    }
  ],
  "relationships": {
    "commonly_combined": [
      ["distributed_processing", "auto_scaling"],
      ["neural_learning", "performance_optimization"]
    ],
    "prerequisites": {
      "auto_scaling": ["distributed_processing"],
      "advanced_coordination": ["distributed_processing", "neural_learning"]
    }
  }
}
```

### 6. Usage Analytics

#### Get Tool Usage Statistics
```http
GET /tools/{name}/usage
```

**Query Parameters:**
- `timeframe` (string): 1h, 24h, 7d, 30d (default: 7d)
- `breakdown` (enum): user, session, geography, parameter (default: none)

**Response:**
```json
{
  "tool": "swarm_init",
  "timeframe": "7d",
  "usage": {
    "totalExecutions": 2108,
    "uniqueUsers": 156,
    "uniqueSessions": 234,
    "averageExecutionsPerUser": 13.5,
    "averageExecutionsPerSession": 9.0
  },
  "trends": {
    "daily": [
      { "date": "2025-01-14", "executions": 342, "users": 28 },
      { "date": "2025-01-13", "executions": 298, "users": 25 },
      { "date": "2025-01-12", "executions": 287, "users": 23 }
    ],
    "hourly": {
      "peak": { "hour": 14, "executions": 45 },
      "low": { "hour": 3, "executions": 12 }
    }
  },
  "parameters": {
    "topology": {
      "mesh": 0.52,
      "hierarchical": 0.31,
      "ring": 0.12,
      "star": 0.05
    },
    "maxAgents": {
      "1-5": 0.38,
      "6-10": 0.45,
      "11-20": 0.17
    }
  },
  "outcomes": {
    "successRate": 0.995,
    "averageExecutionTime": 45.2,
    "commonErrors": [
      {
        "error": "insufficient_resources",
        "frequency": 0.003,
        "resolution": "Reduce maxAgents or increase system resources"
      }
    ]
  }
}
```

#### Get Global Usage Metrics
```http
GET /usage/global
```

**Response:**
```json
{
  "timeframe": "24h",
  "overview": {
    "totalExecutions": 8945,
    "activeUsers": 245,
    "activeSessions": 456,
    "totalTools": 27,
    "mostUsedTools": [
      { "name": "swarm_init", "executions": 1205, "percentage": 13.5 },
      { "name": "task_orchestrate", "executions": 987, "percentage": 11.0 },
      { "name": "agent_spawn", "executions": 876, "percentage": 9.8 }
    ]
  },
  "categories": {
    "swarm": 4521,
    "neural": 2108,
    "memory": 1456,
    "performance": 765,
    "github": 95
  },
  "geography": {
    "north_america": 0.45,
    "europe": 0.32,
    "asia": 0.18,
    "other": 0.05
  },
  "performance": {
    "averageResponseTime": 127,
    "successRate": 0.994,
    "p95ResponseTime": 450
  }
}
```

### 7. Tool Feedback and Quality

#### Submit Tool Feedback
```http
POST /tools/{name}/feedback
```

**Request Body:**
```json
{
  "rating": 4,
  "context": "Used for coordinating file processing across multiple agents",
  "feedback": "Works reliably but initialization could be faster",
  "executionTime": 1200,
  "success": true,
  "parameters": {
    "topology": "mesh",
    "maxAgents": 8
  },
  "additionalData": {
    "useCase": "batch_processing",
    "teamSize": "small",
    "complexity": "medium"
  }
}
```

**Response:**
```json
{
  "feedbackId": "fb_1735123456789_abc123",
  "message": "Feedback submitted successfully",
  "tool": "swarm_init",
  "processing": {
    "willUpdateRecommendations": true,
    "willUpdatePerformanceMetrics": true,
    "estimatedImpact": "low"
  },
  "thankyou": {
    "points": 10,
    "contribution": "Your feedback helps improve tool recommendations for all users"
  }
}
```

#### Get Tool Quality Metrics
```http
GET /tools/{name}/quality
```

**Response:**
```json
{
  "tool": "swarm_init",
  "quality": {
    "overall": 4.6,
    "reliability": 4.8,
    "performance": 4.4,
    "usability": 4.5,
    "documentation": 4.3
  },
  "feedback": {
    "totalRatings": 256,
    "ratingDistribution": {
      "5": 142,
      "4": 89,
      "3": 21,
      "2": 3,
      "1": 1
    },
    "commonPraise": [
      "Reliable and consistent performance",
      "Easy to understand and use",
      "Good error messages"
    ],
    "commonCriticisms": [
      "Initialization could be faster",
      "Documentation could be more detailed",
      "Limited configuration options"
    ]
  },
  "improvements": {
    "inProgress": [
      "Performance optimization for initialization",
      "Enhanced documentation with more examples"
    ],
    "planned": [
      "Additional topology options",
      "Better error recovery mechanisms"
    ]
  }
}
```

### 8. Health and Monitoring

#### Registry Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T15:30:00Z",
  "version": "2.0.0",
  "uptime": 432000,
  "services": {
    "database": {
      "status": "healthy",
      "responseTime": 12,
      "connections": { "active": 15, "max": 100 }
    },
    "cache": {
      "status": "healthy",
      "hitRatio": 0.85,
      "memoryUsage": 0.67
    },
    "search": {
      "status": "healthy",
      "indexSize": 156789,
      "queryTime": 8
    }
  },
  "metrics": {
    "requestsPerSecond": 125.6,
    "averageResponseTime": 45.2,
    "errorRate": 0.001
  }
}
```

#### Registry Metrics (Prometheus Format)
```http
GET /metrics
```

**Response:**
```
# HELP registry_tools_total Total number of tools in registry
# TYPE registry_tools_total gauge
registry_tools_total 27

# HELP registry_requests_total Total requests to registry API
# TYPE registry_requests_total counter
registry_requests_total{method="GET",endpoint="/tools"} 15420
registry_requests_total{method="POST",endpoint="/tools/recommend"} 3421

# HELP registry_response_time_seconds Response time of registry requests
# TYPE registry_response_time_seconds histogram
registry_response_time_seconds_bucket{le="0.01"} 1234
registry_response_time_seconds_bucket{le="0.05"} 5432
registry_response_time_seconds_bucket{le="0.1"} 8765

# HELP registry_tool_executions_total Total tool executions tracked
# TYPE registry_tool_executions_total counter
registry_tool_executions_total{tool="swarm_init",success="true"} 15343
registry_tool_executions_total{tool="swarm_init",success="false"} 77
```

## Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "TOOL_NOT_FOUND",
    "message": "Tool 'invalid_tool' does not exist",
    "details": {
      "tool": "invalid_tool",
      "suggestions": ["swarm_init", "swarm_status"],
      "levenshteinDistance": 2
    },
    "timestamp": "2025-01-15T15:30:00Z",
    "requestId": "req_1735123456789"
  }
}
```

### Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `TOOL_NOT_FOUND` | 404 | Requested tool does not exist |
| `INVALID_PARAMETERS` | 400 | Request parameters are invalid |
| `SEARCH_ERROR` | 500 | Search service error |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `SERVICE_UNAVAILABLE` | 503 | Registry temporarily unavailable |

## Rate Limiting

### Limits by Endpoint

| Endpoint | Rate Limit | Window |
|----------|------------|---------|
| `GET /tools` | 1000 req/hour | Rolling |
| `GET /tools/{name}` | 5000 req/hour | Rolling |
| `GET /tools/search` | 500 req/hour | Rolling |
| `POST /tools/recommend` | 100 req/hour | Rolling |
| `POST /tools/{name}/feedback` | 50 req/hour | Rolling |

### Rate Limit Headers
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 985
X-RateLimit-Reset: 1735123456
X-RateLimit-Window: 3600
```

## Webhook Integration

### Tool Update Notifications
```http
POST /webhooks/register
```

**Request Body:**
```json
{
  "url": "https://your-app.com/webhooks/tools",
  "events": ["tool.updated", "tool.deprecated", "performance.degraded"],
  "filters": {
    "tools": ["swarm_init", "task_orchestrate"],
    "categories": ["swarm"]
  },
  "secret": "webhook-signing-secret"
}
```

### Webhook Payload Example
```json
{
  "event": "tool.updated",
  "timestamp": "2025-01-15T15:30:00Z",
  "data": {
    "tool": "swarm_init",
    "version": "2.0.1",
    "changes": ["Performance improvements", "Bug fixes"],
    "breaking": false,
    "migrationRequired": false
  },
  "signature": "sha256=..."
}
```

## SDK Examples

### JavaScript/Node.js
```javascript
const { FANNToolsRegistry } = require('@fann/tools-registry');

const registry = new FANNToolsRegistry({
  apiKey: process.env.FANN_API_KEY,
  baseUrl: 'https://api.fann.ai/v2'
});

// Get tool recommendations
const recommendations = await registry.recommend({
  context: 'Coordinate multiple AI agents for data processing',
  preferences: { performance: 'high' }
});

// Search tools
const searchResults = await registry.search('neural training');

// Get tool details
const tool = await registry.getTool('swarm_init');
```

### Python
```python
from fann_tools_registry import ToolsRegistry

registry = ToolsRegistry(
    api_key=os.getenv('FANN_API_KEY'),
    base_url='https://api.fann.ai/v2'
)

# Get recommendations
recommendations = registry.recommend(
    context="Coordinate multiple AI agents",
    preferences={"performance": "high"}
)

# Search tools
results = registry.search("neural training")

# Get tool details
tool = registry.get_tool("swarm_init")
```

### cURL Examples
```bash
# List all swarm tools
curl -H "Authorization: Bearer $API_KEY" \
  "https://api.fann.ai/v2/tools?category=swarm"

# Get tool details
curl -H "Authorization: Bearer $API_KEY" \
  "https://api.fann.ai/v2/tools/swarm_init"

# Search tools
curl -H "Authorization: Bearer $API_KEY" \
  "https://api.fann.ai/v2/tools/search?q=neural%20training"

# Get recommendations
curl -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"context":"AI agent coordination","preferences":{"performance":"high"}}' \
  "https://api.fann.ai/v2/tools/recommend"
```

## OpenAPI Specification

The complete OpenAPI 3.0 specification is available at:
- **Production**: `https://api.fann.ai/v2/openapi.json`
- **Interactive Docs**: `https://api.fann.ai/v2/docs`

## Changelog

### v2.0.0 (2025-01-15)
- Complete API redesign with enhanced tool discovery
- Added semantic search capabilities
- Introduced personalized recommendations
- Added comprehensive analytics and feedback system
- Improved performance metrics and monitoring

### v1.1.0 (2024-12-01)
- Added tool compatibility matrix
- Enhanced search with fuzzy matching
- Introduced webhook notifications
- Added usage analytics

### v1.0.0 (2024-10-01)
- Initial API release
- Basic tool discovery and introspection
- Simple search functionality
- Basic performance metrics

This API provides a comprehensive foundation for tool discovery, intelligent recommendations, and ecosystem management within the FANN MCP tools integration.