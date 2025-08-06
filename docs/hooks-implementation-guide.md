# Hooks System Implementation Guide

## Overview

This guide provides step-by-step implementation details for the sophisticated hooks system architecture. It includes code examples, database schemas, API specifications, and deployment instructions.

## Table of Contents

1. [Core Hook Manager Implementation](#core-hook-manager-implementation)
2. [Pre-execution Hooks](#pre-execution-hooks)
3. [Post-execution Hooks](#post-execution-hooks)
4. [MCP Tools Registry API](#mcp-tools-registry-api)
5. [Session Management](#session-management)
6. [Neural Enhancement Layer](#neural-enhancement-layer)
7. [Database Schema](#database-schema)
8. [API Specifications](#api-specifications)
9. [Integration Examples](#integration-examples)
10. [Testing Strategy](#testing-strategy)

## Core Hook Manager Implementation

### Hook Manager Class

```typescript
// src/core/HookManager.ts
import { EventEmitter } from 'events';
import { Logger } from '../utils/Logger';
import { MetricsCollector } from '../monitoring/MetricsCollector';
import { NeuralEngine } from '../neural/NeuralEngine';

interface Hook {
  name: string;
  type: HookType;
  priority: number;
  execute(args: HookArgs, context: ExecutionContext): Promise<HookResult>;
}

interface HookResult {
  continue: boolean;
  error?: string;
  warnings?: string[];
  optimizations?: Optimization[];
  metadata?: Record<string, any>;
  duration?: number;
}

interface ExecutionContext {
  sessionId: string;
  userId?: string;
  timestamp: number;
  sequenceId: string;
  parentOperation?: string;
}

export class HookManager extends EventEmitter {
  private hooks: Map<HookType, Hook[]> = new Map();
  private metrics: MetricsCollector;
  private neural: NeuralEngine;
  private logger: Logger;
  
  constructor(config: HookManagerConfig) {
    super();
    this.metrics = new MetricsCollector(config.metrics);
    this.neural = new NeuralEngine(config.neural);
    this.logger = new Logger('HookManager');
    
    this.setupBuiltinHooks();
  }
  
  /**
   * Register a hook for specific execution points
   */
  registerHook(hook: Hook): void {
    if (!this.hooks.has(hook.type)) {
      this.hooks.set(hook.type, []);
    }
    
    const hooks = this.hooks.get(hook.type)!;
    hooks.push(hook);
    
    // Sort by priority (lower numbers execute first)
    hooks.sort((a, b) => a.priority - b.priority);
    
    this.logger.info(`Registered hook: ${hook.name} for type: ${hook.type}`);
    this.emit('hook:registered', { hook });
  }
  
  /**
   * Execute all hooks of a specific type
   */
  async executeHooks(
    type: HookType,
    args: HookArgs,
    context: ExecutionContext
  ): Promise<HookExecutionResult> {
    const startTime = Date.now();
    const hooks = this.hooks.get(type) || [];
    
    if (hooks.length === 0) {
      return {
        success: true,
        continue: true,
        results: [],
        duration: 0
      };
    }
    
    this.logger.debug(`Executing ${hooks.length} hooks for type: ${type}`);
    this.metrics.increment('hooks.execution.started', { type });
    
    const results: HookResult[] = [];
    let shouldContinue = true;
    
    try {
      // Execute hooks based on their execution strategy
      if (this.shouldExecuteParallel(type)) {
        results.push(...await this.executeParallel(hooks, args, context));
      } else {
        results.push(...await this.executeSequential(hooks, args, context));
      }
      
      // Check if any hook wants to stop execution
      shouldContinue = results.every(result => result.continue !== false);
      
      // Aggregate optimizations and warnings
      const aggregatedResult = this.aggregateResults(results);
      
      // Learn from execution patterns
      await this.neural.learnFromExecution(type, args, results, context);
      
      const duration = Date.now() - startTime;
      this.metrics.histogram('hooks.execution.duration', duration, { type });
      this.metrics.increment('hooks.execution.completed', { 
        type, 
        success: 'true',
        continue: shouldContinue.toString()
      });
      
      this.emit('hooks:executed', {
        type,
        duration,
        hookCount: hooks.length,
        continue: shouldContinue,
        results: aggregatedResult
      });
      
      return {
        success: true,
        continue: shouldContinue,
        results,
        aggregated: aggregatedResult,
        duration
      };
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.logger.error(`Hook execution failed for type ${type}:`, error);
      this.metrics.increment('hooks.execution.error', { type });
      
      // Return non-blocking error to allow operation to continue
      return {
        success: false,
        continue: true, // Don't block on hook failures
        error: error.message,
        results,
        duration
      };
    }
  }
  
  /**
   * Execute hooks in parallel for performance
   */
  private async executeParallel(
    hooks: Hook[],
    args: HookArgs,
    context: ExecutionContext
  ): Promise<HookResult[]> {
    const promises = hooks.map(async (hook) => {
      const hookContext = { ...context, hookName: hook.name };
      
      try {
        const startTime = Date.now();
        const result = await Promise.race([
          hook.execute(args, hookContext),
          this.createTimeoutPromise(hook.name, 5000) // 5 second timeout
        ]);
        
        result.duration = Date.now() - startTime;
        this.metrics.histogram('hook.execution.duration', result.duration, {
          hook: hook.name,
          type: hook.type
        });
        
        return result;
      } catch (error) {
        this.logger.warn(`Hook ${hook.name} failed:`, error);
        return {
          continue: true, // Non-blocking
          error: `Hook ${hook.name} failed: ${error.message}`,
          duration: 0
        };
      }
    });
    
    const settledResults = await Promise.allSettled(promises);
    return settledResults.map((result, index) => {
      if (result.status === 'fulfilled') {
        return result.value;
      } else {
        this.logger.warn(`Hook ${hooks[index].name} rejected:`, result.reason);
        return {
          continue: true,
          error: `Hook ${hooks[index].name} rejected: ${result.reason.message}`,
          duration: 0
        };
      }
    });
  }
  
  /**
   * Execute hooks sequentially for dependencies
   */
  private async executeSequential(
    hooks: Hook[],
    args: HookArgs,
    context: ExecutionContext
  ): Promise<HookResult[]> {
    const results: HookResult[] = [];
    
    for (const hook of hooks) {
      try {
        const startTime = Date.now();
        const result = await hook.execute(args, { ...context, hookName: hook.name });
        result.duration = Date.now() - startTime;
        
        results.push(result);
        
        // Stop if hook wants to block execution
        if (result.continue === false) {
          this.logger.info(`Hook ${hook.name} requested execution stop`);
          break;
        }
        
      } catch (error) {
        this.logger.warn(`Hook ${hook.name} failed:`, error);
        results.push({
          continue: true,
          error: `Hook ${hook.name} failed: ${error.message}`,
          duration: 0
        });
      }
    }
    
    return results;
  }
  
  private createTimeoutPromise(hookName: string, timeoutMs: number): Promise<HookResult> {
    return new Promise((_, reject) => {
      setTimeout(() => {
        reject(new Error(`Hook ${hookName} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });
  }
  
  private aggregateResults(results: HookResult[]): AggregatedHookResult {
    const aggregated: AggregatedHookResult = {
      totalDuration: results.reduce((sum, r) => sum + (r.duration || 0), 0),
      warnings: [],
      optimizations: [],
      metadata: {},
      hookCount: results.length,
      successCount: results.filter(r => !r.error).length,
      errorCount: results.filter(r => r.error).length
    };
    
    for (const result of results) {
      if (result.warnings) aggregated.warnings.push(...result.warnings);
      if (result.optimizations) aggregated.optimizations.push(...result.optimizations);
      if (result.metadata) Object.assign(aggregated.metadata, result.metadata);
    }
    
    return aggregated;
  }
  
  private setupBuiltinHooks(): void {
    // Register built-in hooks
    this.registerHook(new PreToolValidationHook(this.neural));
    this.registerHook(new PostToolLearningHook(this.neural, this.metrics));
    this.registerHook(new SessionStateHook());
    this.registerHook(new SecurityValidationHook());
    this.registerHook(new PerformanceMonitoringHook(this.metrics));
  }
  
  private shouldExecuteParallel(type: HookType): boolean {
    // Pre-hooks generally execute in parallel for performance
    // Post-hooks may need sequential execution for dependencies
    const parallelTypes: HookType[] = [
      'pre-tool',
      'pre-file',
      'validation',
      'optimization'
    ];
    
    return parallelTypes.includes(type);
  }
}
```

## Pre-execution Hooks

### Pre-Tool Validation Hook

```typescript
// src/hooks/PreToolValidationHook.ts
import { Hook, HookArgs, HookResult, ExecutionContext } from '../types/Hook';
import { ToolsRegistry } from '../registry/ToolsRegistry';
import { SwarmStateManager } from '../swarm/SwarmStateManager';
import { NeuralEngine } from '../neural/NeuralEngine';

interface PreToolArgs extends HookArgs {
  tool: string;
  params: Record<string, any>;
  expectedResult?: any;
}

export class PreToolValidationHook implements Hook {
  name = 'pre-tool-validation';
  type = 'pre-tool' as const;
  priority = 100;
  
  constructor(
    private registry: ToolsRegistry,
    private swarmState: SwarmStateManager,
    private neural: NeuralEngine
  ) {}
  
  async execute(args: PreToolArgs, context: ExecutionContext): Promise<HookResult> {
    const { tool, params } = args;
    const validations: ValidationResult[] = [];
    const optimizations: Optimization[] = [];
    const warnings: string[] = [];
    
    try {
      // 1. Tool existence and schema validation
      const toolDefinition = await this.registry.getToolDefinition(tool);
      if (!toolDefinition) {
        return {
          continue: false,
          error: `Unknown tool: ${tool}`,
          metadata: { validationStep: 'tool_existence' }
        };
      }
      
      const schemaValidation = await this.validateSchema(toolDefinition, params);
      validations.push(schemaValidation);
      
      if (!schemaValidation.valid) {
        warnings.push(`Schema validation failed: ${schemaValidation.errors.join(', ')}`);
      }
      
      // 2. Resource and dependency checks
      const resourceCheck = await this.validateResources(tool, params, context);
      validations.push(resourceCheck);
      
      if (!resourceCheck.sufficient) {
        optimizations.push({
          type: 'resource-preparation',
          description: 'Prepare required resources for optimal execution',
          actions: resourceCheck.requiredActions,
          estimatedBenefit: 'Prevent execution failures and improve performance'
        });
      }
      
      // 3. Swarm state validation (for swarm-related tools)
      if (this.isSwarmTool(tool)) {
        const swarmValidation = await this.validateSwarmState(tool, params);
        validations.push(swarmValidation);
        
        if (!swarmValidation.ready) {
          optimizations.push({
            type: 'swarm-initialization',
            description: 'Initialize or prepare swarm for operation',
            actions: ['swarm_init', 'agent_spawn'],
            autoExecutable: true,
            estimatedBenefit: 'Enable distributed processing capabilities'
          });
        }
      }
      
      // 4. Parameter optimization using neural patterns
      const paramOptimization = await this.optimizeParameters(tool, params, context);
      if (paramOptimization.hasOptimizations) {
        optimizations.push({
          type: 'parameter-optimization',
          description: 'Optimize parameters based on learned patterns',
          originalParams: params,
          optimizedParams: paramOptimization.optimizedParams,
          confidence: paramOptimization.confidence,
          estimatedBenefit: `${Math.round(paramOptimization.expectedImprovement * 100)}% performance improvement`
        });
      }
      
      // 5. Security and safety checks
      const securityCheck = await this.validateSecurity(tool, params, context);
      if (!securityCheck.safe) {
        return {
          continue: false,
          error: `Security validation failed: ${securityCheck.reason}`,
          metadata: { 
            securityLevel: securityCheck.level,
            recommendations: securityCheck.recommendations 
          }
        };
      }
      
      // 6. Performance predictions
      const performancePrediction = await this.predictPerformance(tool, params, context);
      
      return {
        continue: true,
        optimizations,
        warnings,
        metadata: {
          validationsPassed: validations.filter(v => v.valid).length,
          validationsTotal: validations.length,
          optimizationCount: optimizations.length,
          performancePrediction,
          toolDefinition: {
            name: toolDefinition.name,
            version: toolDefinition.version,
            category: toolDefinition.category
          }
        }
      };
      
    } catch (error) {
      return {
        continue: true, // Don't block on validation errors
        error: `Validation hook failed: ${error.message}`,
        warnings: ['Pre-validation failed, proceeding with default behavior']
      };
    }
  }
  
  private async validateSchema(
    toolDefinition: ToolDefinition, 
    params: Record<string, any>
  ): Promise<ValidationResult> {
    const schema = toolDefinition.schema;
    const validator = new JSONSchemaValidator(schema);
    
    try {
      const result = validator.validate(params);
      return {
        type: 'schema',
        valid: result.valid,
        errors: result.errors || [],
        metadata: { schema: schema.title || 'unknown' }
      };
    } catch (error) {
      return {
        type: 'schema',
        valid: false,
        errors: [`Schema validation error: ${error.message}`]
      };
    }
  }
  
  private async validateResources(
    tool: string,
    params: Record<string, any>,
    context: ExecutionContext
  ): Promise<ResourceValidation> {
    const requirements = await this.getResourceRequirements(tool, params);
    const available = await this.getAvailableResources();
    const requiredActions: string[] = [];
    
    // Check memory requirements
    if (requirements.memory > available.memory * 0.8) { // 80% threshold
      requiredActions.push('optimize-memory-usage');
    }
    
    // Check agent requirements
    if (requirements.agents > available.agents) {
      requiredActions.push(`spawn-agents:${requirements.agents - available.agents}`);
    }
    
    // Check database connections
    if (requirements.dbConnections > available.dbConnections) {
      requiredActions.push('expand-connection-pool');
    }
    
    return {
      type: 'resource',
      sufficient: requiredActions.length === 0,
      requirements,
      available,
      requiredActions,
      utilizationPrediction: this.calculateUtilization(requirements, available)
    };
  }
  
  private async validateSwarmState(
    tool: string,
    params: Record<string, any>
  ): Promise<SwarmValidation> {
    const state = await this.swarmState.getCurrentState();
    const toolRequirements = this.getSwarmRequirements(tool);
    
    return {
      type: 'swarm',
      ready: this.isSwarmReady(state, toolRequirements),
      currentState: state,
      requirements: toolRequirements,
      recommendations: this.generateSwarmRecommendations(state, toolRequirements)
    };
  }
  
  private async optimizeParameters(
    tool: string,
    params: Record<string, any>,
    context: ExecutionContext
  ): Promise<ParameterOptimization> {
    // Use neural engine to predict optimal parameters
    const historicalData = await this.neural.getHistoricalPerformance(tool, params);
    const patterns = await this.neural.getOptimizationPatterns(tool);
    
    if (historicalData.length < 5) {
      // Not enough data for optimization
      return { hasOptimizations: false, confidence: 0 };
    }
    
    const optimizedParams = await this.neural.optimizeParameters(
      tool,
      params,
      patterns,
      historicalData,
      context
    );
    
    const expectedImprovement = this.calculateExpectedImprovement(
      params,
      optimizedParams,
      historicalData
    );
    
    return {
      hasOptimizations: expectedImprovement > 0.05, // 5% threshold
      optimizedParams,
      confidence: this.calculateConfidence(patterns, historicalData),
      expectedImprovement
    };
  }
  
  private async predictPerformance(
    tool: string,
    params: Record<string, any>,
    context: ExecutionContext
  ): Promise<PerformancePrediction> {
    const historicalMetrics = await this.neural.getPerformanceHistory(tool, params);
    const systemLoad = await this.getCurrentSystemLoad();
    
    return {
      estimatedDuration: this.predictDuration(historicalMetrics, systemLoad),
      estimatedMemoryUsage: this.predictMemoryUsage(tool, params),
      estimatedCpuUsage: this.predictCpuUsage(tool, params),
      confidence: this.calculatePredictionConfidence(historicalMetrics),
      bottlenecks: await this.identifyPotentialBottlenecks(tool, params, systemLoad)
    };
  }
  
  private isSwarmTool(tool: string): boolean {
    const swarmTools = [
      'swarm_init', 'swarm_status', 'swarm_monitor',
      'agent_spawn', 'agent_list', 'agent_metrics',
      'task_orchestrate', 'task_status', 'task_results'
    ];
    return swarmTools.some(st => tool.includes(st));
  }
}
```

### Pre-File Operation Hook

```typescript
// src/hooks/PreFileOperationHook.ts
export class PreFileOperationHook implements Hook {
  name = 'pre-file-operation';
  type = 'pre-file' as const;
  priority = 200;
  
  constructor(
    private agentManager: AgentManager,
    private conflictDetector: ConflictDetector,
    private backupManager: BackupManager
  ) {}
  
  async execute(args: PreFileArgs, context: ExecutionContext): Promise<HookResult> {
    const { operation, filePath, content } = args;
    const optimizations: Optimization[] = [];
    const warnings: string[] = [];
    
    try {
      // 1. Agent assignment based on file type
      const fileType = this.detectFileType(filePath);
      const agent = await this.agentManager.getOptimalAgent(fileType, operation);
      
      if (!agent) {
        // Suggest spawning appropriate agent
        optimizations.push({
          type: 'agent-spawning',
          description: `Spawn ${this.getAgentTypeForFile(fileType)} agent for optimal ${operation} operation`,
          actions: [`spawn-agent:${this.getAgentTypeForFile(fileType)}`],
          autoExecutable: true,
          estimatedBenefit: 'Specialized handling and improved performance'
        });
      }
      
      // 2. Conflict detection
      const conflicts = await this.conflictDetector.checkConflicts(filePath, operation);
      if (conflicts.length > 0) {
        warnings.push(`Potential conflicts detected: ${conflicts.map(c => c.description).join(', ')}`);
        
        optimizations.push({
          type: 'conflict-resolution',
          description: 'Resolve file conflicts before proceeding',
          actions: conflicts.map(c => c.resolution),
          estimatedBenefit: 'Prevent data loss and merge conflicts'
        });
      }
      
      // 3. Backup creation for destructive operations
      if (this.isDestructiveOperation(operation) && await this.fileExists(filePath)) {
        const backupCreated = await this.backupManager.createBackup(filePath);
        
        optimizations.push({
          type: 'backup-created',
          description: 'Backup created for safety',
          actions: [`backup:${backupCreated.backupPath}`],
          metadata: { backupPath: backupCreated.backupPath }
        });
      }
      
      // 4. Formatting and linting preparation
      if (operation === 'write' || operation === 'edit') {
        const formatters = await this.getAvailableFormatters(fileType);
        if (formatters.length > 0) {
          optimizations.push({
            type: 'auto-formatting',
            description: 'Auto-format file after modification',
            actions: formatters.map(f => `format:${f}`),
            metadata: { formatters }
          });
        }
      }
      
      // 5. Permission and access checks
      const accessCheck = await this.checkFileAccess(filePath, operation);
      if (!accessCheck.allowed) {
        return {
          continue: false,
          error: `File access denied: ${accessCheck.reason}`,
          metadata: { requiredPermissions: accessCheck.requiredPermissions }
        };
      }
      
      return {
        continue: true,
        optimizations,
        warnings,
        metadata: {
          assignedAgent: agent?.id,
          agentType: agent?.type,
          fileType,
          backupCreated: this.isDestructiveOperation(operation),
          conflictsDetected: conflicts.length,
          formattersAvailable: (await this.getAvailableFormatters(fileType)).length
        }
      };
      
    } catch (error) {
      return {
        continue: true,
        error: `Pre-file hook failed: ${error.message}`,
        warnings: ['File operation proceeding without optimization']
      };
    }
  }
  
  private detectFileType(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const typeMap: Record<string, string> = {
      '.js': 'javascript',
      '.ts': 'typescript', 
      '.jsx': 'react',
      '.tsx': 'react-typescript',
      '.py': 'python',
      '.rs': 'rust',
      '.go': 'golang',
      '.java': 'java',
      '.cpp': 'cpp',
      '.c': 'c',
      '.md': 'markdown',
      '.json': 'json',
      '.yaml': 'yaml',
      '.yml': 'yaml',
      '.toml': 'toml',
      '.sql': 'sql'
    };
    
    return typeMap[ext] || 'text';
  }
  
  private getAgentTypeForFile(fileType: string): string {
    const agentMap: Record<string, string> = {
      'javascript': 'coder',
      'typescript': 'coder',
      'react': 'coder',
      'python': 'coder',
      'rust': 'coder',
      'markdown': 'researcher',
      'json': 'analyst',
      'yaml': 'analyst',
      'sql': 'analyst'
    };
    
    return agentMap[fileType] || 'coordinator';
  }
  
  private isDestructiveOperation(operation: string): boolean {
    return ['write', 'delete', 'edit'].includes(operation);
  }
}
```

## Post-execution Hooks

### Post-Tool Learning Hook

```typescript
// src/hooks/PostToolLearningHook.ts
export class PostToolLearningHook implements Hook {
  name = 'post-tool-learning';
  type = 'post-tool' as const;
  priority = 100;
  
  constructor(
    private neural: NeuralEngine,
    private metrics: MetricsCollector,
    private cacheManager: CacheManager
  ) {}
  
  async execute(args: PostToolArgs, context: ExecutionContext): Promise<HookResult> {
    const { tool, params, result, duration, success } = args;
    const learningResults: LearningResult[] = [];
    const recommendations: Recommendation[] = [];
    
    try {
      // 1. Collect execution metrics
      const executionMetrics = {
        tool,
        params,
        result,
        duration,
        success,
        timestamp: Date.now(),
        context: {
          sessionId: context.sessionId,
          sequencePosition: context.sequenceId,
          systemLoad: await this.getCurrentSystemLoad()
        }
      };
      
      await this.metrics.recordToolExecution(executionMetrics);
      
      // 2. Extract patterns for neural learning
      const patterns = await this.extractPatterns(executionMetrics);
      const patternLearning = await this.neural.learnPatterns(tool, patterns);
      learningResults.push(patternLearning);
      
      // 3. Update performance baselines
      const performanceUpdate = await this.updatePerformanceBaselines(
        tool, 
        params, 
        duration, 
        success
      );
      learningResults.push(performanceUpdate);
      
      // 4. Cache management
      const cacheUpdate = await this.updateCache(tool, params, result, success);
      
      // 5. Generate recommendations for future executions
      if (success) {
        const futureRecommendations = await this.generateRecommendations(
          tool,
          params,
          result,
          patterns,
          context
        );
        recommendations.push(...futureRecommendations);
      }
      
      // 6. Failure analysis and learning
      if (!success) {
        const failureAnalysis = await this.analyzeFailure(
          tool,
          params,
          result,
          context
        );
        learningResults.push(failureAnalysis);
      }
      
      // 7. Cross-tool correlation analysis
      const correlationLearning = await this.analyzeToolCorrelations(
        tool,
        params,
        context
      );
      learningResults.push(correlationLearning);
      
      return {
        continue: true,
        metadata: {
          patternsLearned: patternLearning.newPatterns.length,
          baselineUpdated: performanceUpdate.updated,
          cacheUpdated: cacheUpdate.updated,
          recommendationsGenerated: recommendations.length,
          failureInsights: success ? 0 : 1,
          correlationsFound: correlationLearning.correlations.length,
          totalLearningConfidence: this.calculateAverageLearningConfidence(learningResults),
          nextOptimizations: recommendations.map(r => r.optimization)
        },
        optimizations: recommendations.map(r => r.optimization)
      };
      
    } catch (error) {
      // Non-blocking learning failure
      return {
        continue: true,
        error: `Learning hook failed: ${error.message}`,
        metadata: { learningSkipped: true }
      };
    }
  }
  
  private async extractPatterns(metrics: ExecutionMetrics): Promise<Pattern[]> {
    const patterns: Pattern[] = [];
    
    // Parameter patterns
    patterns.push({
      type: 'parameter-success',
      tool: metrics.tool,
      parameters: this.normalizeParameters(metrics.params),
      outcome: metrics.success ? 'success' : 'failure',
      performance: {
        duration: metrics.duration,
        memoryUsed: metrics.context.systemLoad.memory,
        cpuUsed: metrics.context.systemLoad.cpu
      },
      context: {
        sessionPhase: this.determineSessionPhase(metrics.context),
        timeOfDay: new Date().getHours(),
        systemLoad: metrics.context.systemLoad.overall
      }
    });
    
    // Result structure patterns (for successful executions)
    if (metrics.success && metrics.result) {
      patterns.push({
        type: 'result-structure',
        tool: metrics.tool,
        resultSchema: this.extractResultSchema(metrics.result),
        dataComplexity: this.calculateDataComplexity(metrics.result),
        performance: metrics.duration
      });
    }
    
    // Temporal execution patterns
    patterns.push({
      type: 'temporal-execution',
      tool: metrics.tool,
      executionTime: new Date(),
      sequencePosition: metrics.context.sequencePosition,
      precedingOperations: await this.getRecentOperations(metrics.context.sessionId, 5),
      systemState: metrics.context.systemLoad
    });
    
    // Error patterns (for failed executions)
    if (!metrics.success && metrics.result?.error) {
      patterns.push({
        type: 'error-pattern',
        tool: metrics.tool,
        errorType: this.classifyError(metrics.result.error),
        parameters: metrics.params,
        systemState: metrics.context.systemLoad,
        context: metrics.context
      });
    }
    
    return patterns;
  }
  
  private async updatePerformanceBaselines(
    tool: string,
    params: Record<string, any>,
    duration: number,
    success: boolean
  ): Promise<LearningResult> {
    const parameterHash = this.hashParameters(params);
    const existingBaseline = await this.neural.getPerformanceBaseline(tool, parameterHash);
    
    const newDataPoint = {
      duration,
      success,
      timestamp: Date.now(),
      parameters: params
    };
    
    if (!existingBaseline) {
      // Create new baseline
      await this.neural.createPerformanceBaseline(tool, parameterHash, {
        averageDuration: duration,
        successRate: success ? 1.0 : 0.0,
        sampleCount: 1,
        dataPoints: [newDataPoint],
        confidence: 0.1 // Low confidence with single sample
      });
      
      return {
        type: 'baseline-creation',
        updated: true,
        confidence: 0.1,
        details: 'Created new performance baseline'
      };
    } else {
      // Update existing baseline
      const updatedBaseline = this.calculateUpdatedBaseline(existingBaseline, newDataPoint);
      await this.neural.updatePerformanceBaseline(tool, parameterHash, updatedBaseline);
      
      return {
        type: 'baseline-update',
        updated: true,
        confidence: updatedBaseline.confidence,
        improvement: this.calculateImprovement(existingBaseline, updatedBaseline),
        details: `Updated baseline with ${updatedBaseline.sampleCount} samples`
      };
    }
  }
  
  private async generateRecommendations(
    tool: string,
    params: Record<string, any>,
    result: any,
    patterns: Pattern[],
    context: ExecutionContext
  ): Promise<Recommendation[]> {
    const recommendations: Recommendation[] = [];
    
    // Parameter optimization recommendations
    const paramOptimization = await this.neural.recommendParameterOptimizations(
      tool,
      params,
      patterns
    );
    
    if (paramOptimization.hasRecommendations) {
      recommendations.push({
        type: 'parameter-optimization',
        confidence: paramOptimization.confidence,
        optimization: {
          type: 'parameter-tuning',
          description: `Optimize ${tool} parameters for better performance`,
          originalParams: params,
          recommendedParams: paramOptimization.recommendedParams,
          expectedImprovement: paramOptimization.expectedImprovement,
          estimatedBenefit: `${Math.round(paramOptimization.expectedImprovement * 100)}% performance gain`
        }
      });
    }
    
    // Tool sequence recommendations
    const sequenceRecommendations = await this.neural.recommendToolSequences(
      tool,
      result,
      context
    );
    
    for (const seqRec of sequenceRecommendations) {
      recommendations.push({
        type: 'tool-sequence',
        confidence: seqRec.confidence,
        optimization: {
          type: 'workflow-optimization',
          description: `Consider following ${tool} with ${seqRec.nextTool}`,
          nextTool: seqRec.nextTool,
          suggestedParams: seqRec.suggestedParams,
          estimatedBenefit: seqRec.benefit
        }
      });
    }
    
    // Resource optimization recommendations
    if (this.detectResourceBottleneck(patterns)) {
      recommendations.push({
        type: 'resource-optimization',
        confidence: 0.8,
        optimization: {
          type: 'resource-scaling',
          description: 'Scale resources to improve performance',
          actions: ['spawn-additional-agents', 'increase-memory-allocation'],
          estimatedBenefit: '20-40% performance improvement'
        }
      });
    }
    
    return recommendations;
  }
  
  private async analyzeFailure(
    tool: string,
    params: Record<string, any>,
    result: any,
    context: ExecutionContext
  ): Promise<LearningResult> {
    const errorType = this.classifyError(result.error);
    const failurePattern = await this.neural.analyzeFailurePattern(
      tool,
      params,
      errorType,
      context
    );
    
    return {
      type: 'failure-analysis',
      updated: true,
      confidence: failurePattern.confidence,
      patterns: [failurePattern.pattern],
      recommendations: failurePattern.preventionStrategies,
      details: `Analyzed ${errorType} failure for future prevention`
    };
  }
  
  private classifyError(error: string): string {
    const errorPatterns = {
      'timeout': /timeout|timed out/i,
      'permission': /permission|access denied|unauthorized/i,
      'resource': /memory|cpu|resource|out of/i,
      'validation': /validation|invalid|schema/i,
      'network': /network|connection|unreachable/i,
      'dependency': /dependency|module|import/i
    };
    
    for (const [type, pattern] of Object.entries(errorPatterns)) {
      if (pattern.test(error)) {
        return type;
      }
    }
    
    return 'unknown';
  }
}
```

## MCP Tools Registry API

### Registry API Implementation

```typescript
// src/registry/ToolsRegistryAPI.ts
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { ToolsRegistry } from './ToolsRegistry';
import { SearchEngine } from './SearchEngine';
import { RecommendationEngine } from './RecommendationEngine';

interface ToolQuery {
  q?: string;
  category?: string;
  capability?: string[];
  complexity?: 'simple' | 'medium' | 'complex';
  performance?: 'low' | 'medium' | 'high';
  limit?: number;
  offset?: number;
}

interface RecommendationRequest {
  context: string;
  currentTools?: string[];
  preferences?: {
    performance?: 'low' | 'medium' | 'high';
    complexity?: 'simple' | 'medium' | 'complex';
    reliability?: 'standard' | 'high';
  };
  constraints?: {
    maxTools?: number;
    excludeTools?: string[];
    requireCapabilities?: string[];
  };
}

export class ToolsRegistryAPI {
  constructor(
    private registry: ToolsRegistry,
    private searchEngine: SearchEngine,
    private recommendationEngine: RecommendationEngine
  ) {}
  
  async registerRoutes(fastify: FastifyInstance): Promise<void> {
    
    // GET /api/v2/tools - List all tools with filtering
    fastify.get('/api/v2/tools', {
      schema: {
        querystring: {
          type: 'object',
          properties: {
            category: { type: 'string' },
            capability: { type: 'array', items: { type: 'string' } },
            complexity: { type: 'string', enum: ['simple', 'medium', 'complex'] },
            performance: { type: 'string', enum: ['low', 'medium', 'high'] },
            limit: { type: 'integer', minimum: 1, maximum: 100, default: 50 },
            offset: { type: 'integer', minimum: 0, default: 0 }
          }
        }
      }
    }, this.getTools.bind(this));
    
    // GET /api/v2/tools/search - Search tools
    fastify.get('/api/v2/tools/search', {
      schema: {
        querystring: {
          type: 'object',
          required: ['q'],
          properties: {
            q: { type: 'string', minLength: 1 },
            category: { type: 'string' },
            limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 }
          }
        }
      }
    }, this.searchTools.bind(this));
    
    // GET /api/v2/tools/:name - Get specific tool
    fastify.get('/api/v2/tools/:name', {
      schema: {
        params: {
          type: 'object',
          required: ['name'],
          properties: {
            name: { type: 'string', pattern: '^[a-zA-Z0-9_-]+$' }
          }
        }
      }
    }, this.getTool.bind(this));
    
    // GET /api/v2/tools/:name/schema - Get tool schema
    fastify.get('/api/v2/tools/:name/schema', this.getToolSchema.bind(this));
    
    // GET /api/v2/tools/:name/examples - Get tool examples
    fastify.get('/api/v2/tools/:name/examples', this.getToolExamples.bind(this));
    
    // GET /api/v2/tools/:name/performance - Get tool performance metrics
    fastify.get('/api/v2/tools/:name/performance', this.getToolPerformance.bind(this));
    
    // POST /api/v2/tools/recommend - Get tool recommendations
    fastify.post('/api/v2/tools/recommend', {
      schema: {
        body: {
          type: 'object',
          required: ['context'],
          properties: {
            context: { type: 'string', minLength: 10 },
            currentTools: { type: 'array', items: { type: 'string' } },
            preferences: {
              type: 'object',
              properties: {
                performance: { type: 'string', enum: ['low', 'medium', 'high'] },
                complexity: { type: 'string', enum: ['simple', 'medium', 'complex'] },
                reliability: { type: 'string', enum: ['standard', 'high'] }
              }
            },
            constraints: {
              type: 'object',
              properties: {
                maxTools: { type: 'integer', minimum: 1, maximum: 20 },
                excludeTools: { type: 'array', items: { type: 'string' } },
                requireCapabilities: { type: 'array', items: { type: 'string' } }
              }
            }
          }
        }
      }
    }, this.recommendTools.bind(this));
    
    // GET /api/v2/categories - List tool categories
    fastify.get('/api/v2/categories', this.getCategories.bind(this));
    
    // GET /api/v2/capabilities - List available capabilities
    fastify.get('/api/v2/capabilities', this.getCapabilities.bind(this));
    
    // GET /api/v2/metrics - Registry health metrics
    fastify.get('/api/v2/metrics', this.getMetrics.bind(this));
    
    // POST /api/v2/tools/:name/feedback - Submit tool feedback
    fastify.post('/api/v2/tools/:name/feedback', {
      schema: {
        params: {
          type: 'object',
          required: ['name'],
          properties: {
            name: { type: 'string' }
          }
        },
        body: {
          type: 'object',
          required: ['rating', 'context'],
          properties: {
            rating: { type: 'integer', minimum: 1, maximum: 5 },
            context: { type: 'string' },
            feedback: { type: 'string' },
            executionTime: { type: 'number' },
            success: { type: 'boolean' }
          }
        }
      }
    }, this.submitFeedback.bind(this));
  }
  
  private async getTools(
    request: FastifyRequest<{ Querystring: ToolQuery }>,
    reply: FastifyReply
  ): Promise<void> {
    try {
      const { category, capability, complexity, performance, limit = 50, offset = 0 } = request.query;
      
      const filters = {
        category,
        capabilities: capability ? (Array.isArray(capability) ? capability : [capability]) : undefined,
        complexity,
        performance,
        limit,
        offset
      };
      
      const result = await this.registry.getTools(filters);
      
      reply.send({
        tools: result.tools,
        pagination: {
          total: result.total,
          limit,
          offset,
          hasMore: offset + limit < result.total
        },
        metadata: {
          categories: await this.registry.getAvailableCategories(),
          capabilities: await this.registry.getAvailableCapabilities(),
          totalTools: result.total
        }
      });
      
    } catch (error) {
      reply.status(500).send({
        error: 'Internal server error',
        message: error.message
      });
    }
  }
  
  private async searchTools(
    request: FastifyRequest<{ Querystring: { q: string; category?: string; limit?: number } }>,
    reply: FastifyReply
  ): Promise<void> {
    try {
      const { q, category, limit = 20 } = request.query;
      
      const searchResults = await this.searchEngine.search({
        query: q,
        category,
        limit,
        includeScore: true,
        fuzzyMatch: true
      });
      
      reply.send({
        query: q,
        results: searchResults.results,
        metadata: {
          totalMatches: searchResults.totalMatches,
          searchTime: searchResults.searchTime,
          suggestions: searchResults.suggestions
        }
      });
      
    } catch (error) {
      reply.status(500).send({
        error: 'Search failed',
        message: error.message
      });
    }
  }
  
  private async getTool(
    request: FastifyRequest<{ Params: { name: string } }>,
    reply: FastifyReply
  ): Promise<void> {
    try {
      const { name } = request.params;
      const tool = await this.registry.getTool(name);
      
      if (!tool) {
        reply.status(404).send({
          error: 'Tool not found',
          message: `Tool '${name}' does not exist`
        });
        return;
      }
      
      // Include additional metadata
      const [performance, usage, dependencies] = await Promise.all([
        this.registry.getToolPerformance(name),
        this.registry.getToolUsageStats(name),
        this.registry.getToolDependencies(name)
      ]);
      
      reply.send({
        ...tool,
        performance,
        usage,
        dependencies,
        metadata: {
          lastUpdated: tool.lastUpdated,
          registeredAt: tool.registeredAt,
          version: tool.version
        }
      });
      
    } catch (error) {
      reply.status(500).send({
        error: 'Failed to retrieve tool',
        message: error.message
      });
    }
  }
  
  private async recommendTools(
    request: FastifyRequest<{ Body: RecommendationRequest }>,
    reply: FastifyReply
  ): Promise<void> {
    try {
      const { context, currentTools = [], preferences = {}, constraints = {} } = request.body;
      
      const recommendations = await this.recommendationEngine.recommend({
        context,
        currentTools,
        preferences: {
          performance: preferences.performance || 'medium',
          complexity: preferences.complexity || 'medium',
          reliability: preferences.reliability || 'standard'
        },
        constraints: {
          maxTools: constraints.maxTools || 10,
          excludeTools: constraints.excludeTools || [],
          requireCapabilities: constraints.requireCapabilities || []
        }
      });
      
      reply.send({
        context: context.substring(0, 100) + '...',
        recommendations: recommendations.tools.map(tool => ({
          name: tool.name,
          category: tool.category,
          confidence: tool.confidence,
          reasoning: tool.reasoning,
          expectedBenefit: tool.expectedBenefit,
          integrationComplexity: tool.integrationComplexity,
          estimatedTime: tool.estimatedTime
        })),
        workflow: recommendations.suggestedWorkflow,
        metadata: {
          totalRecommendations: recommendations.tools.length,
          averageConfidence: recommendations.averageConfidence,
          analysisTime: recommendations.analysisTime
        }
      });
      
    } catch (error) {
      reply.status(500).send({
        error: 'Recommendation failed',
        message: error.message
      });
    }
  }
  
  private async submitFeedback(
    request: FastifyRequest<{
      Params: { name: string };
      Body: {
        rating: number;
        context: string;
        feedback?: string;
        executionTime?: number;
        success?: boolean;
      };
    }>,
    reply: FastifyReply
  ): Promise<void> {
    try {
      const { name } = request.params;
      const { rating, context, feedback, executionTime, success } = request.body;
      
      await this.registry.submitFeedback(name, {
        rating,
        context,
        feedback,
        executionTime,
        success,
        timestamp: Date.now(),
        userId: request.headers['user-id'] as string, // From auth middleware
        sessionId: request.headers['session-id'] as string
      });
      
      reply.send({
        message: 'Feedback submitted successfully',
        tool: name,
        feedbackId: `fb_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
      });
      
    } catch (error) {
      reply.status(500).send({
        error: 'Failed to submit feedback',
        message: error.message
      });
    }
  }
}
```

### Tool Definition Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "MCP Tool Definition",
  "type": "object",
  "required": ["name", "version", "category", "description", "schema"],
  "properties": {
    "name": {
      "type": "string",
      "pattern": "^[a-zA-Z][a-zA-Z0-9_]*$",
      "description": "Unique tool identifier"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version"
    },
    "category": {
      "type": "string",
      "enum": ["swarm", "neural", "memory", "daa", "performance", "github", "workflow", "system"],
      "description": "Tool category for organization"
    },
    "description": {
      "type": "string",
      "minLength": 10,
      "maxLength": 200,
      "description": "Brief tool description"
    },
    "schema": {
      "type": "object",
      "description": "JSON Schema for tool parameters"
    },
    "performance": {
      "type": "object",
      "properties": {
        "averageLatency": {
          "type": "string",
          "pattern": "^\\d+(\\.\\d+)?(ms|s|m)$"
        },
        "throughput": {
          "type": "string",
          "description": "Operations per second (e.g., '1000/s')"
        },
        "successRate": {
          "type": "number",
          "minimum": 0,
          "maximum": 1
        },
        "resourceUsage": {
          "type": "string",
          "enum": ["low", "medium", "high"]
        },
        "scalability": {
          "type": "string",
          "enum": ["linear", "logarithmic", "exponential", "constant"]
        }
      }
    },
    "dependencies": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "version": { "type": "string" },
          "required": { "type": "boolean", "default": true },
          "type": {
            "type": "string",
            "enum": ["tool", "service", "library", "model"]
          }
        }
      }
    },
    "capabilities": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "distributed_processing",
          "neural_learning",
          "persistent_memory",
          "real_time_monitoring",
          "auto_scaling",
          "conflict_resolution",
          "pattern_recognition",
          "performance_optimization"
        ]
      }
    },
    "hooks": {
      "type": "object",
      "properties": {
        "pre": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Pre-execution hook types"
        },
        "post": {
          "type": "array", 
          "items": { "type": "string" },
          "description": "Post-execution hook types"
        }
      }
    },
    "examples": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "description": { "type": "string" },
          "params": { "type": "object" },
          "expectedResult": { "type": "object" },
          "complexity": {
            "type": "string",
            "enum": ["simple", "medium", "complex"]
          }
        }
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "author": { "type": "string" },
        "tags": {
          "type": "array",
          "items": { "type": "string" }
        },
        "documentation": { "type": "string", "format": "uri" },
        "repository": { "type": "string", "format": "uri" },
        "license": { "type": "string" },
        "stability": {
          "type": "string",
          "enum": ["experimental", "beta", "stable", "deprecated"]
        }
      }
    }
  }
}
```

## Session Management

### Session Manager Implementation

```typescript
// src/session/SessionManager.ts
import { Redis } from 'ioredis';
import { Pool } from 'pg';
import { SessionState, SessionConfig, Session } from '../types/Session';
import { Logger } from '../utils/Logger';

export class SessionManager {
  private redis: Redis;
  private postgres: Pool;
  private logger: Logger;
  private activeSessions: Map<string, Session> = new Map();
  
  constructor(config: SessionManagerConfig) {
    this.redis = new Redis(config.redisUrl);
    this.postgres = new Pool(config.postgresConfig);
    this.logger = new Logger('SessionManager');
    
    this.setupCleanupInterval();
  }
  
  async initializeSession(config: SessionConfig): Promise<Session> {
    const sessionId = this.generateSessionId();
    const session: Session = {
      id: sessionId,
      userId: config.userId,
      createdAt: Date.now(),
      lastActivity: Date.now(),
      state: {
        swarmConfig: null,
        agents: new Map(),
        memory: new Map(),
        metrics: {
          operationsCount: 0,
          tokensProcessed: 0,
          patterns: [],
          improvements: []
        },
        context: {
          currentTask: null,
          recentOperations: [],
          preferences: config.preferences || {}
        }
      },
      metadata: {
        clientVersion: config.clientVersion,
        features: config.enabledFeatures || [],
        preferences: config.preferences || {}
      }
    };
    
    // Store in both memory and persistent storage
    this.activeSessions.set(sessionId, session);
    await this.persistSession(session);
    
    this.logger.info(`Initialized session ${sessionId} for user ${config.userId}`);
    return session;
  }
  
  async restoreSession(sessionId: string): Promise<Session | null> {
    // Try memory first for performance
    let session = this.activeSessions.get(sessionId);
    
    if (!session) {
      // Load from persistent storage
      session = await this.loadSessionFromStorage(sessionId);
      
      if (session) {
        // Restore to memory
        this.activeSessions.set(sessionId, session);
        this.logger.info(`Restored session ${sessionId} from storage`);
      }
    }
    
    if (session) {
      session.lastActivity = Date.now();
      await this.updateSessionActivity(sessionId);
    }
    
    return session;
  }
  
  async updateSessionState(
    sessionId: string,
    stateUpdates: Partial<SessionState>
  ): Promise<void> {
    const session = await this.restoreSession(sessionId);
    
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }
    
    // Deep merge state updates
    session.state = {
      ...session.state,
      ...stateUpdates,
      memory: new Map([
        ...session.state.memory,
        ...(stateUpdates.memory || new Map())
      ]),
      agents: new Map([
        ...session.state.agents,
        ...(stateUpdates.agents || new Map())
      ])
    };
    
    session.lastActivity = Date.now();
    
    // Update both memory and storage
    this.activeSessions.set(sessionId, session);
    await this.persistSession(session);
    
    // Cache frequently accessed data in Redis
    await this.cacheSessionData(sessionId, session);
  }
  
  async storeMemory(
    sessionId: string,
    key: string,
    value: any,
    ttl?: number
  ): Promise<void> {
    const session = await this.restoreSession(sessionId);
    
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }
    
    // Store in session state
    session.state.memory.set(key, {
      value,
      timestamp: Date.now(),
      ttl: ttl ? Date.now() + ttl : null,
      accessCount: 0
    });
    
    // Also store in Redis for fast access
    const redisKey = `session:${sessionId}:memory:${key}`;
    const redisValue = JSON.stringify({
      value,
      timestamp: Date.now(),
      sessionId
    });
    
    if (ttl) {
      await this.redis.setex(redisKey, Math.ceil(ttl / 1000), redisValue);
    } else {
      await this.redis.set(redisKey, redisValue);
    }
    
    await this.updateSessionState(sessionId, { memory: session.state.memory });
  }
  
  async retrieveMemory(sessionId: string, key: string): Promise<any> {
    // Try Redis first for performance
    const redisKey = `session:${sessionId}:memory:${key}`;
    const redisValue = await this.redis.get(redisKey);
    
    if (redisValue) {
      const data = JSON.parse(redisValue);
      
      // Update access count in session state
      const session = this.activeSessions.get(sessionId);
      if (session && session.state.memory.has(key)) {
        const memoryItem = session.state.memory.get(key)!;
        memoryItem.accessCount++;
        memoryItem.lastAccessed = Date.now();
      }
      
      return data.value;
    }
    
    // Fallback to session state
    const session = await this.restoreSession(sessionId);
    if (!session) {
      return null;
    }
    
    const memoryItem = session.state.memory.get(key);
    if (!memoryItem) {
      return null;
    }
    
    // Check TTL
    if (memoryItem.ttl && Date.now() > memoryItem.ttl) {
      session.state.memory.delete(key);
      await this.updateSessionState(sessionId, { memory: session.state.memory });
      return null;
    }
    
    memoryItem.accessCount++;
    memoryItem.lastAccessed = Date.now();
    
    return memoryItem.value;
  }
  
  async searchMemory(sessionId: string, pattern: string): Promise<MemorySearchResult[]> {
    const session = await this.restoreSession(sessionId);
    
    if (!session) {
      return [];
    }
    
    const results: MemorySearchResult[] = [];
    const regex = new RegExp(pattern, 'i');
    
    for (const [key, memoryItem] of session.state.memory) {
      // Search in key and stringified value
      const searchText = `${key} ${JSON.stringify(memoryItem.value)}`;
      
      if (regex.test(searchText)) {
        results.push({
          key,
          value: memoryItem.value,
          relevanceScore: this.calculateRelevanceScore(searchText, pattern),
          timestamp: memoryItem.timestamp,
          accessCount: memoryItem.accessCount || 0
        });
      }
    }
    
    // Sort by relevance score
    return results.sort((a, b) => b.relevanceScore - a.relevanceScore);
  }
  
  async terminateSession(sessionId: string): Promise<SessionSummary> {
    const session = await this.restoreSession(sessionId);
    
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }
    
    const summary: SessionSummary = {
      sessionId,
      userId: session.userId,
      duration: Date.now() - session.createdAt,
      operations: session.state.metrics.operationsCount,
      tokensProcessed: session.state.metrics.tokensProcessed,
      patternsLearned: session.state.metrics.patterns.length,
      improvements: session.state.metrics.improvements.length,
      memoryItems: session.state.memory.size,
      agentsSpawned: session.state.agents.size,
      finalState: this.serializeSessionState(session.state)
    };
    
    // Archive session data
    await this.archiveSession(session, summary);
    
    // Clean up
    this.activeSessions.delete(sessionId);
    await this.cleanupSessionData(sessionId);
    
    this.logger.info(`Terminated session ${sessionId}`, summary);
    return summary;
  }
  
  private generateSessionId(): string {
    return `sess_${Date.now()}_${Math.random().toString(36).substr(2, 12)}`;
  }
  
  private async persistSession(session: Session): Promise<void> {
    try {
      // Store main session data in PostgreSQL
      const query = `
        INSERT INTO sessions (id, user_id, created_at, last_activity, state, metadata)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (id) DO UPDATE SET
          last_activity = EXCLUDED.last_activity,
          state = EXCLUDED.state,
          metadata = EXCLUDED.metadata
      `;
      
      await this.postgres.query(query, [
        session.id,
        session.userId,
        new Date(session.createdAt),
        new Date(session.lastActivity),
        JSON.stringify(this.serializeSessionState(session.state)),
        JSON.stringify(session.metadata)
      ]);
      
    } catch (error) {
      this.logger.error(`Failed to persist session ${session.id}:`, error);
      throw new Error(`Session persistence failed: ${error.message}`);
    }
  }
  
  private async loadSessionFromStorage(sessionId: string): Promise<Session | null> {
    try {
      const query = 'SELECT * FROM sessions WHERE id = $1';
      const result = await this.postgres.query(query, [sessionId]);
      
      if (result.rows.length === 0) {
        return null;
      }
      
      const row = result.rows[0];
      
      return {
        id: row.id,
        userId: row.user_id,
        createdAt: row.created_at.getTime(),
        lastActivity: row.last_activity.getTime(),
        state: this.deserializeSessionState(JSON.parse(row.state)),
        metadata: JSON.parse(row.metadata)
      };
      
    } catch (error) {
      this.logger.error(`Failed to load session ${sessionId}:`, error);
      return null;
    }
  }
  
  private serializeSessionState(state: SessionState): any {
    return {
      swarmConfig: state.swarmConfig,
      agents: Array.from(state.agents.entries()),
      memory: Array.from(state.memory.entries()),
      metrics: state.metrics,
      context: state.context
    };
  }
  
  private deserializeSessionState(serialized: any): SessionState {
    return {
      swarmConfig: serialized.swarmConfig,
      agents: new Map(serialized.agents || []),
      memory: new Map(serialized.memory || []),
      metrics: serialized.metrics || {
        operationsCount: 0,
        tokensProcessed: 0,
        patterns: [],
        improvements: []
      },
      context: serialized.context || {
        currentTask: null,
        recentOperations: [],
        preferences: {}
      }
    };
  }
  
  private setupCleanupInterval(): void {
    // Clean up expired sessions every hour
    setInterval(async () => {
      await this.cleanupExpiredSessions();
    }, 60 * 60 * 1000);
  }
  
  private async cleanupExpiredSessions(): Promise<void> {
    const expireTime = Date.now() - (24 * 60 * 60 * 1000); // 24 hours
    
    try {
      // Clean up from memory
      for (const [sessionId, session] of this.activeSessions) {
        if (session.lastActivity < expireTime) {
          this.activeSessions.delete(sessionId);
        }
      }
      
      // Clean up from database
      const query = 'DELETE FROM sessions WHERE last_activity < $1';
      const result = await this.postgres.query(query, [new Date(expireTime)]);
      
      if (result.rowCount > 0) {
        this.logger.info(`Cleaned up ${result.rowCount} expired sessions`);
      }
      
    } catch (error) {
      this.logger.error('Session cleanup failed:', error);
    }
  }
}
```

## Database Schema

### PostgreSQL Schema

```sql
-- Database schema for hooks system
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sessions table
CREATE TABLE sessions (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_activity TIMESTAMP NOT NULL DEFAULT NOW(),
    state JSONB NOT NULL DEFAULT '{}',
    metadata JSONB NOT NULL DEFAULT '{}',
    
    INDEX idx_sessions_user_id (user_id),
    INDEX idx_sessions_last_activity (last_activity),
    INDEX idx_sessions_state_gin (state) USING GIN
);

-- Tools registry table
CREATE TABLE tools (
    name VARCHAR(255) PRIMARY KEY,
    version VARCHAR(32) NOT NULL,
    category VARCHAR(64) NOT NULL,
    description TEXT NOT NULL,
    schema JSONB NOT NULL,
    performance JSONB,
    dependencies JSONB DEFAULT '[]',
    capabilities TEXT[] DEFAULT ARRAY[]::TEXT[],
    hooks JSONB DEFAULT '{}',
    examples JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_tools_category (category),
    INDEX idx_tools_capabilities (capabilities) USING GIN,
    INDEX idx_tools_schema_gin (schema) USING GIN
);

-- Tool execution metrics
CREATE TABLE tool_executions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(64) REFERENCES sessions(id) ON DELETE CASCADE,
    tool_name VARCHAR(255) NOT NULL,
    params JSONB NOT NULL,
    result JSONB,
    duration INTEGER NOT NULL, -- milliseconds
    success BOOLEAN NOT NULL,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    context JSONB DEFAULT '{}',
    
    INDEX idx_tool_executions_session (session_id),
    INDEX idx_tool_executions_tool (tool_name),
    INDEX idx_tool_executions_created_at (created_at),
    INDEX idx_tool_executions_success (success),
    INDEX idx_tool_executions_params_gin (params) USING GIN
);

-- Hook executions table
CREATE TABLE hook_executions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(64) REFERENCES sessions(id) ON DELETE CASCADE,
    hook_type VARCHAR(64) NOT NULL,
    hook_name VARCHAR(255) NOT NULL,
    execution_id VARCHAR(64), -- Links to parent operation
    args JSONB NOT NULL,
    result JSONB,
    duration INTEGER NOT NULL, -- milliseconds
    success BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_hook_executions_session (session_id),
    INDEX idx_hook_executions_type (hook_type),
    INDEX idx_hook_executions_name (hook_name),
    INDEX idx_hook_executions_execution_id (execution_id)
);

-- Neural patterns table
CREATE TABLE neural_patterns (
    id SERIAL PRIMARY KEY,
    pattern_type VARCHAR(64) NOT NULL,
    tool_name VARCHAR(255),
    pattern_data JSONB NOT NULL,
    confidence FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    sample_count INTEGER NOT NULL DEFAULT 1,
    success_rate FLOAT NOT NULL CHECK (success_rate >= 0 AND success_rate <= 1),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_neural_patterns_type (pattern_type),
    INDEX idx_neural_patterns_tool (tool_name),
    INDEX idx_neural_patterns_confidence (confidence),
    INDEX idx_neural_patterns_data_gin (pattern_data) USING GIN,
    
    UNIQUE (pattern_type, tool_name, MD5(pattern_data::TEXT))
);

-- Performance baselines table
CREATE TABLE performance_baselines (
    id SERIAL PRIMARY KEY,
    tool_name VARCHAR(255) NOT NULL,
    param_hash VARCHAR(64) NOT NULL, -- MD5 of normalized parameters
    avg_duration FLOAT NOT NULL,
    success_rate FLOAT NOT NULL CHECK (success_rate >= 0 AND success_rate <= 1),
    sample_count INTEGER NOT NULL,
    confidence FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_baselines_tool (tool_name),
    INDEX idx_baselines_hash (param_hash),
    INDEX idx_baselines_confidence (confidence),
    
    UNIQUE (tool_name, param_hash)
);

-- Tool feedback table
CREATE TABLE tool_feedback (
    id SERIAL PRIMARY KEY,
    tool_name VARCHAR(255) NOT NULL,
    user_id VARCHAR(255),
    session_id VARCHAR(64),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    context TEXT NOT NULL,
    feedback TEXT,
    execution_time INTEGER, -- milliseconds
    success BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_feedback_tool (tool_name),
    INDEX idx_feedback_user (user_id),
    INDEX idx_feedback_rating (rating),
    INDEX idx_feedback_created_at (created_at)
);

-- Swarm states table
CREATE TABLE swarm_states (
    id VARCHAR(64) PRIMARY KEY,
    session_id VARCHAR(64) REFERENCES sessions(id) ON DELETE CASCADE,
    topology VARCHAR(32) NOT NULL,
    max_agents INTEGER NOT NULL,
    current_agents INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'initializing',
    config JSONB NOT NULL DEFAULT '{}',
    agents JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_swarm_states_session (session_id),
    INDEX idx_swarm_states_status (status),
    INDEX idx_swarm_states_topology (topology)
);

-- Memory cache table for cross-session persistence
CREATE TABLE memory_cache (
    id SERIAL PRIMARY KEY,
    key VARCHAR(512) NOT NULL,
    value JSONB NOT NULL,
    namespace VARCHAR(255) NOT NULL DEFAULT 'default',
    ttl TIMESTAMP, -- NULL for no expiration
    access_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_accessed TIMESTAMP NOT NULL DEFAULT NOW(),
    
    INDEX idx_memory_cache_key (key),
    INDEX idx_memory_cache_namespace (namespace),
    INDEX idx_memory_cache_ttl (ttl),
    INDEX idx_memory_cache_last_accessed (last_accessed),
    INDEX idx_memory_cache_value_gin (value) USING GIN,
    
    UNIQUE (namespace, key)
);

-- Create views for common queries
CREATE VIEW tool_performance_summary AS
SELECT 
    t.name,
    t.category,
    t.version,
    COUNT(te.id) as execution_count,
    AVG(te.duration) as avg_duration,
    AVG(CASE WHEN te.success THEN 1 ELSE 0 END) as success_rate,
    MAX(te.created_at) as last_execution
FROM tools t
LEFT JOIN tool_executions te ON t.name = te.tool_name
WHERE te.created_at >= NOW() - INTERVAL '7 days'
GROUP BY t.name, t.category, t.version;

CREATE VIEW session_activity_summary AS
SELECT 
    s.id,
    s.user_id,
    s.created_at,
    s.last_activity,
    EXTRACT(EPOCH FROM (s.last_activity - s.created_at)) as duration_seconds,
    COUNT(te.id) as tool_executions,
    COUNT(he.id) as hook_executions,
    COALESCE(ss.current_agents, 0) as active_agents
FROM sessions s
LEFT JOIN tool_executions te ON s.id = te.session_id
LEFT JOIN hook_executions he ON s.id = he.session_id
LEFT JOIN swarm_states ss ON s.id = ss.session_id
GROUP BY s.id, s.user_id, s.created_at, s.last_activity, ss.current_agents;

-- Create functions for common operations
CREATE OR REPLACE FUNCTION cleanup_expired_memory()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM memory_cache 
    WHERE ttl IS NOT NULL AND ttl < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_tool_performance(
    tool_name_param VARCHAR(255),
    duration_param INTEGER,
    success_param BOOLEAN
) RETURNS VOID AS $$
BEGIN
    INSERT INTO performance_baselines (
        tool_name, 
        param_hash, 
        avg_duration, 
        success_rate, 
        sample_count, 
        confidence
    )
    VALUES (
        tool_name_param,
        'default',
        duration_param::FLOAT,
        CASE WHEN success_param THEN 1.0 ELSE 0.0 END,
        1,
        0.1
    )
    ON CONFLICT (tool_name, param_hash) DO UPDATE SET
        avg_duration = (performance_baselines.avg_duration * performance_baselines.sample_count + duration_param) / (performance_baselines.sample_count + 1),
        success_rate = (performance_baselines.success_rate * performance_baselines.sample_count + CASE WHEN success_param THEN 1.0 ELSE 0.0 END) / (performance_baselines.sample_count + 1),
        sample_count = performance_baselines.sample_count + 1,
        confidence = LEAST(1.0, performance_baselines.confidence + 0.01),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Setup automated cleanup job
CREATE OR REPLACE FUNCTION schedule_cleanup()
RETURNS VOID AS $$
BEGIN
    -- This would typically be handled by a cron job or scheduled task
    -- Clean up expired memory cache entries
    PERFORM cleanup_expired_memory();
    
    -- Archive old sessions (older than 30 days)
    UPDATE sessions SET metadata = metadata || '{"archived": true}'
    WHERE last_activity < NOW() - INTERVAL '30 days'
    AND NOT (metadata ? 'archived');
END;
$$ LANGUAGE plpgsql;
```

## Testing Strategy

### Unit Tests

```typescript
// tests/hooks/HookManager.test.ts
import { HookManager } from '../../src/core/HookManager';
import { MockNeuralEngine } from '../mocks/MockNeuralEngine';
import { MockMetricsCollector } from '../mocks/MockMetricsCollector';

describe('HookManager', () => {
  let hookManager: HookManager;
  let mockNeuralEngine: MockNeuralEngine;
  let mockMetrics: MockMetricsCollector;
  
  beforeEach(() => {
    mockNeuralEngine = new MockNeuralEngine();
    mockMetrics = new MockMetricsCollector();
    
    hookManager = new HookManager({
      neural: mockNeuralEngine,
      metrics: mockMetrics
    });
  });
  
  describe('executeHooks', () => {
    it('should execute all hooks of specified type', async () => {
      const mockHook1 = {
        name: 'test-hook-1',
        type: 'pre-tool',
        priority: 100,
        execute: jest.fn().mockResolvedValue({
          continue: true,
          metadata: { executed: true }
        })
      };
      
      const mockHook2 = {
        name: 'test-hook-2', 
        type: 'pre-tool',
        priority: 200,
        execute: jest.fn().mockResolvedValue({
          continue: true,
          optimizations: [{ type: 'test', description: 'test optimization' }]
        })
      };
      
      hookManager.registerHook(mockHook1);
      hookManager.registerHook(mockHook2);
      
      const result = await hookManager.executeHooks('pre-tool', {
        tool: 'test-tool',
        params: { test: true }
      }, {
        sessionId: 'test-session',
        timestamp: Date.now(),
        sequenceId: '1'
      });
      
      expect(result.success).toBe(true);
      expect(result.continue).toBe(true);
      expect(result.results).toHaveLength(2);
      expect(mockHook1.execute).toHaveBeenCalled();
      expect(mockHook2.execute).toHaveBeenCalled();
    });
    
    it('should respect hook priorities', async () => {
      const executionOrder: string[] = [];
      
      const highPriorityHook = {
        name: 'high-priority',
        type: 'pre-tool',
        priority: 50,
        execute: jest.fn().mockImplementation(async () => {
          executionOrder.push('high');
          return { continue: true };
        })
      };
      
      const lowPriorityHook = {
        name: 'low-priority',
        type: 'pre-tool', 
        priority: 200,
        execute: jest.fn().mockImplementation(async () => {
          executionOrder.push('low');
          return { continue: true };
        })
      };
      
      hookManager.registerHook(lowPriorityHook); // Register in reverse order
      hookManager.registerHook(highPriorityHook);
      
      await hookManager.executeHooks('pre-tool', {}, {
        sessionId: 'test',
        timestamp: Date.now(),
        sequenceId: '1'
      });
      
      expect(executionOrder).toEqual(['high', 'low']);
    });
    
    it('should handle hook failures gracefully', async () => {
      const failingHook = {
        name: 'failing-hook',
        type: 'pre-tool',
        priority: 100,
        execute: jest.fn().mockRejectedValue(new Error('Hook failed'))
      };
      
      const successfulHook = {
        name: 'successful-hook',
        type: 'pre-tool',
        priority: 200,
        execute: jest.fn().mockResolvedValue({ continue: true })
      };
      
      hookManager.registerHook(failingHook);
      hookManager.registerHook(successfulHook);
      
      const result = await hookManager.executeHooks('pre-tool', {}, {
        sessionId: 'test',
        timestamp: Date.now(),
        sequenceId: '1'
      });
      
      expect(result.success).toBe(true); // Should not fail due to one hook failing
      expect(result.continue).toBe(true);
      expect(result.results).toHaveLength(2);
      expect(result.results[0].error).toContain('Hook failed');
      expect(result.results[1].error).toBeUndefined();
    });
    
    it('should stop execution when hook returns continue: false', async () => {
      const blockingHook = {
        name: 'blocking-hook',
        type: 'pre-tool',
        priority: 100,
        execute: jest.fn().mockResolvedValue({
          continue: false,
          error: 'Blocking execution'
        })
      };
      
      const laterHook = {
        name: 'later-hook',
        type: 'pre-tool',
        priority: 200,
        execute: jest.fn().mockResolvedValue({ continue: true })
      };
      
      hookManager.registerHook(blockingHook);
      hookManager.registerHook(laterHook);
      
      const result = await hookManager.executeHooks('pre-tool', {}, {
        sessionId: 'test',
        timestamp: Date.now(),
        sequenceId: '1'
      });
      
      expect(result.continue).toBe(false);
      expect(blockingHook.execute).toHaveBeenCalled();
      expect(laterHook.execute).not.toHaveBeenCalled(); // Should not execute due to blocking
    });
    
    it('should aggregate results correctly', async () => {
      const hook1 = {
        name: 'hook-1',
        type: 'pre-tool',
        priority: 100,
        execute: jest.fn().mockResolvedValue({
          continue: true,
          warnings: ['Warning 1'],
          optimizations: [{ type: 'opt1', description: 'Optimization 1' }],
          metadata: { data1: 'value1' }
        })
      };
      
      const hook2 = {
        name: 'hook-2',
        type: 'pre-tool',
        priority: 200,
        execute: jest.fn().mockResolvedValue({
          continue: true,
          warnings: ['Warning 2'],
          optimizations: [{ type: 'opt2', description: 'Optimization 2' }],
          metadata: { data2: 'value2' }
        })
      };
      
      hookManager.registerHook(hook1);
      hookManager.registerHook(hook2);
      
      const result = await hookManager.executeHooks('pre-tool', {}, {
        sessionId: 'test',
        timestamp: Date.now(),
        sequenceId: '1'
      });
      
      expect(result.aggregated.warnings).toEqual(['Warning 1', 'Warning 2']);
      expect(result.aggregated.optimizations).toHaveLength(2);
      expect(result.aggregated.metadata).toEqual({
        data1: 'value1',
        data2: 'value2'
      });
    });
  });
});
```

### Integration Tests

```typescript
// tests/integration/ToolsRegistryAPI.test.ts
import { FastifyInstance } from 'fastify';
import { setupTestApp } from '../utils/testApp';
import { TestDatabase } from '../utils/TestDatabase';

describe('Tools Registry API Integration', () => {
  let app: FastifyInstance;
  let db: TestDatabase;
  
  beforeAll(async () => {
    db = new TestDatabase();
    await db.setup();
    
    app = await setupTestApp({
      database: db.getConnectionConfig()
    });
  });
  
  afterAll(async () => {
    await app.close();
    await db.teardown();
  });
  
  beforeEach(async () => {
    await db.clearData();
    await db.seedTestData();
  });
  
  describe('GET /api/v2/tools', () => {
    it('should return all tools with pagination', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v2/tools?limit=10&offset=0'
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.tools).toBeInstanceOf(Array);
      expect(data.pagination).toBeDefined();
      expect(data.pagination.total).toBeGreaterThan(0);
      expect(data.metadata).toBeDefined();
    });
    
    it('should filter tools by category', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v2/tools?category=swarm'
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.tools).toBeInstanceOf(Array);
      data.tools.forEach(tool => {
        expect(tool.category).toBe('swarm');
      });
    });
    
    it('should filter tools by capabilities', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v2/tools?capability=neural_learning&capability=distributed_processing'
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      data.tools.forEach(tool => {
        expect(
          tool.capabilities.includes('neural_learning') ||
          tool.capabilities.includes('distributed_processing')
        ).toBe(true);
      });
    });
  });
  
  describe('GET /api/v2/tools/search', () => {
    it('should search tools by query', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v2/tools/search?q=neural%20training'
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.query).toBe('neural training');
      expect(data.results).toBeInstanceOf(Array);
      expect(data.metadata.totalMatches).toBeGreaterThanOrEqual(0);
    });
    
    it('should return empty results for non-existent terms', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v2/tools/search?q=nonexistenttoolquery123'
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.results).toHaveLength(0);
      expect(data.metadata.totalMatches).toBe(0);
    });
  });
  
  describe('POST /api/v2/tools/recommend', () => {
    it('should provide tool recommendations based on context', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/v2/tools/recommend',
        payload: {
          context: 'I need to implement a distributed task processing system with neural optimization',
          preferences: {
            performance: 'high',
            complexity: 'medium'
          },
          constraints: {
            maxTools: 5
          }
        }
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.recommendations).toBeInstanceOf(Array);
      expect(data.recommendations.length).toBeLessThanOrEqual(5);
      expect(data.workflow).toBeDefined();
      expect(data.metadata.averageConfidence).toBeGreaterThan(0);
      
      data.recommendations.forEach(rec => {
        expect(rec.name).toBeDefined();
        expect(rec.confidence).toBeGreaterThan(0);
        expect(rec.reasoning).toBeDefined();
        expect(rec.expectedBenefit).toBeDefined();
      });
    });
    
    it('should respect tool exclusions', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/v2/tools/recommend',
        payload: {
          context: 'Set up swarm coordination',
          constraints: {
            excludeTools: ['swarm_init', 'agent_spawn']
          }
        }
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      data.recommendations.forEach(rec => {
        expect(['swarm_init', 'agent_spawn']).not.toContain(rec.name);
      });
    });
  });
  
  describe('Tool feedback', () => {
    it('should accept and store tool feedback', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/api/v2/tools/swarm_init/feedback',
        headers: {
          'user-id': 'test-user-123',
          'session-id': 'test-session-456'
        },
        payload: {
          rating: 4,
          context: 'Used for coordinating multiple agents in distributed task processing',
          feedback: 'Works well but could be faster',
          executionTime: 250,
          success: true
        }
      });
      
      expect(response.statusCode).toBe(200);
      
      const data = JSON.parse(response.payload);
      expect(data.message).toContain('Feedback submitted successfully');
      expect(data.tool).toBe('swarm_init');
      expect(data.feedbackId).toBeDefined();
    });
  });
});
```

## Conclusion

This comprehensive implementation guide provides:

1. **Complete Hook Manager**: Parallel execution, timeout handling, and intelligent aggregation
2. **Pre-execution Hooks**: Validation, optimization, and resource preparation
3. **Post-execution Hooks**: Learning, metrics collection, and recommendation generation
4. **MCP Tools Registry**: Full-featured API with search, recommendations, and feedback
5. **Session Management**: Persistent state, memory management, and cross-session learning
6. **Database Schema**: Optimized for performance with proper indexing and views
7. **Testing Strategy**: Comprehensive unit and integration tests

The system is designed to be production-ready with proper error handling, performance optimization, and scalability considerations. All components work together to provide an intelligent, learning-enabled hooks system that enhances Claude Code's MCP tools integration.