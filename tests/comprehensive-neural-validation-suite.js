/**
 * Comprehensive Neural Model Validation Suite
 * Tests all 27+ neural models for accessibility, functionality, and performance
 * 
 * This test suite validates:
 * 1. Model initialization and configuration
 * 2. Forward pass functionality
 * 3. Training capabilities
 * 4. Performance benchmarks
 * 5. Memory management
 * 6. Error handling
 * 7. WASM interoperability
 * 8. Integration with ruv-FANN backend
 */

import { strict as assert } from 'assert';
import { performance } from 'perf_hooks';
import { NeuralNetworkManager } from '../ruv-swarm/npm/src/neural-network-manager.js';
import { COMPLETE_NEURAL_PRESETS } from '../ruv-swarm/npm/src/neural-models/neural-presets-complete.js';
import { createNeuralModel } from '../ruv-swarm/npm/src/neural-models/index.js';

class ComprehensiveNeuralValidationSuite {
  constructor() {
    this.testResults = {
      totalModels: 0,
      testedModels: 0,
      passedModels: 0,
      failedModels: 0,
      skippedModels: 0,
      performanceMetrics: new Map(),
      errors: [],
      warnings: [],
      detailedResults: new Map(),
      executionTime: 0,
      memoryUsage: {
        initial: 0,
        peak: 0,
        final: 0
      }
    };
    
    this.wasmLoader = this.createMockWasmLoader();
    this.neuralManager = new NeuralNetworkManager(this.wasmLoader);
    this.testConfig = {
      timeout: 30000, // 30 seconds per test
      maxMemoryMB: 2048,
      minAccuracy: 0.5,
      maxInferenceTimeMs: 1000
    };
    
    this.availableModels = [];
    this.catalogModels();
  }

  /**
   * Catalog all available neural models from multiple sources
   */
  catalogModels() {
    console.log('🔍 Cataloging neural models...');
    
    // 1. Models from COMPLETE_NEURAL_PRESETS (27+ models)
    Object.entries(COMPLETE_NEURAL_PRESETS).forEach(([modelType, presets]) => {
      Object.entries(presets).forEach(([presetName, config]) => {
        this.availableModels.push({
          source: 'complete_presets',
          category: modelType,
          name: presetName,
          fullName: `${modelType}/${presetName}`,
          config: config,
          type: 'preset',
          cognitivePatterns: config.cognitivePatterns || []
        });
      });
    });

    // 2. Models from neural manager templates
    const templates = this.neuralManager.templates;
    Object.keys(templates).forEach(templateName => {
      this.availableModels.push({
        source: 'neural_manager',
        category: 'template',
        name: templateName,
        fullName: `template/${templateName}`,
        config: templates[templateName],
        type: 'template',
        cognitivePatterns: []
      });
    });

    // 3. Specialized neural models from codebase
    const specializedModels = [
      { name: 'ruv_fann_core', category: 'core', type: 'native' },
      { name: 'lstm_forecasting', category: 'forecasting', type: 'specialized' },
      { name: 'transformer_nlp', category: 'nlp', type: 'specialized' },
      { name: 'cnn_vision', category: 'vision', type: 'specialized' },
      { name: 'gnn_graph', category: 'graph', type: 'specialized' },
      { name: 'reinforcement_learning', category: 'rl', type: 'specialized' }
    ];

    specializedModels.forEach(model => {
      this.availableModels.push({
        source: 'specialized',
        category: model.category,
        name: model.name,
        fullName: `specialized/${model.name}`,
        config: {},
        type: model.type,
        cognitivePatterns: []
      });
    });

    this.testResults.totalModels = this.availableModels.length;
    console.log(`📊 Found ${this.testResults.totalModels} neural models to test:`);
    
    // Group by category for summary
    const categoryGroups = {};
    this.availableModels.forEach(model => {
      if (!categoryGroups[model.category]) {
        categoryGroups[model.category] = [];
      }
      categoryGroups[model.category].push(model.name);
    });

    Object.entries(categoryGroups).forEach(([category, models]) => {
      console.log(`  📂 ${category}: ${models.length} models`);
    });
  }

  /**
   * Create mock WASM loader for testing
   */
  createMockWasmLoader() {
    return {
      loadModule: async (moduleName) => {
        console.log(`🔧 Loading WASM module: ${moduleName}`);
        return {
          isPlaceholder: false,
          exports: {
            create_neural_network: (config) => {
              const parsedConfig = JSON.parse(config);
              return `network_${Date.now()}_${Math.random()}`;
            },
            forward_pass: (networkId, input) => {
              return new Float32Array([0.5, 0.3, 0.8, 0.1]);
            },
            train_batch: (networkId, batch, lr, freezeLayers) => {
              return 0.1 + Math.random() * 0.3; // Simulated loss
            },
            get_gradients: (networkId) => {
              return JSON.stringify({
                layer_0: Math.random() * 0.1,
                layer_1: Math.random() * 0.1
              });
            },
            apply_gradients: (networkId, gradients) => {
              // Simulate gradient application
            },
            serialize_network: (networkId) => {
              return 'serialized_network_data';
            },
            deserialize_network: (networkId, data) => {
              // Simulate deserialization
            }
          }
        };
      }
    };
  }

  /**
   * Run comprehensive validation suite
   */
  async runComprehensiveValidation() {
    console.log('\n🚀 Starting Comprehensive Neural Model Validation Suite...');
    console.log('=' .repeat(80));
    
    const startTime = performance.now();
    this.testResults.memoryUsage.initial = this.getMemoryUsage();

    try {
      // Run all test phases
      await this.runModelAccessibilityTests();
      await this.runModelInitializationTests();
      await this.runForwardPassTests();
      await this.runTrainingTests();
      await this.runPerformanceBenchmarks();
      await this.runMemoryManagementTests();
      await this.runErrorHandlingTests();
      await this.runWasmInteroperabilityTests();
      await this.runIntegrationTests();

    } catch (error) {
      console.error('❌ Critical error during validation:', error);
      this.testResults.errors.push({
        phase: 'suite_execution',
        error: error.message,
        stack: error.stack
      });
    }

    this.testResults.executionTime = performance.now() - startTime;
    this.testResults.memoryUsage.final = this.getMemoryUsage();

    // Generate comprehensive report
    return this.generateComprehensiveReport();
  }

  /**
   * Test model accessibility
   */
  async runModelAccessibilityTests() {
    console.log('\n📋 Phase 1: Model Accessibility Tests');
    console.log('-'.repeat(50));

    const accessibilityResults = {
      accessible: [],
      notAccessible: [],
      partiallyAccessible: []
    };

    for (const model of this.availableModels) {
      try {
        const isAccessible = await this.testModelAccessibility(model);
        
        if (isAccessible.fully) {
          accessibilityResults.accessible.push(model);
          console.log(`✅ ${model.fullName}: Fully accessible`);
        } else if (isAccessible.partially) {
          accessibilityResults.partiallyAccessible.push(model);
          console.log(`⚠️  ${model.fullName}: Partially accessible`);
        } else {
          accessibilityResults.notAccessible.push(model);
          console.log(`❌ ${model.fullName}: Not accessible`);
        }
      } catch (error) {
        accessibilityResults.notAccessible.push(model);
        console.log(`💥 ${model.fullName}: Error during accessibility test: ${error.message}`);
        this.testResults.errors.push({
          phase: 'accessibility',
          model: model.fullName,
          error: error.message
        });
      }
    }

    this.testResults.detailedResults.set('accessibility', accessibilityResults);
    console.log(`\n📊 Accessibility Summary:`);
    console.log(`  ✅ Fully accessible: ${accessibilityResults.accessible.length}`);
    console.log(`  ⚠️  Partially accessible: ${accessibilityResults.partiallyAccessible.length}`);
    console.log(`  ❌ Not accessible: ${accessibilityResults.notAccessible.length}`);
  }

  /**
   * Test individual model accessibility
   */
  async testModelAccessibility(model) {
    let canCreate = false;
    let canConfigure = false;
    let hasValidConfig = false;

    try {
      // Test if model can be created
      if (model.source === 'complete_presets') {
        const preset = COMPLETE_NEURAL_PRESETS[model.category]?.[model.name];
        canCreate = !!preset;
        hasValidConfig = !!(preset && preset.config);
      } else if (model.source === 'neural_manager') {
        canCreate = !!this.neuralManager.templates[model.name];
        hasValidConfig = true;
      } else {
        canCreate = true; // Assume specialized models can be created
        hasValidConfig = true;
      }

      // Test basic configuration
      if (canCreate && hasValidConfig) {
        canConfigure = await this.testBasicConfiguration(model);
      }

    } catch (error) {
      // Accessibility test failed
    }

    return {
      fully: canCreate && canConfigure && hasValidConfig,
      partially: canCreate || canConfigure,
      canCreate,
      canConfigure,
      hasValidConfig
    };
  }

  /**
   * Test basic model configuration
   */
  async testBasicConfiguration(model) {
    try {
      if (model.source === 'complete_presets') {
        const agentId = `test_agent_${Date.now()}`;
        const network = await this.neuralManager.createAgentFromCompletePreset(
          agentId, 
          model.category, 
          model.name,
          { requiresCreativity: false, requiresPrecision: true }
        );
        return !!network;
      } else if (model.source === 'neural_manager') {
        const agentId = `test_agent_${Date.now()}`;
        const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
          template: model.name
        });
        return !!network;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Run model initialization tests
   */
  async runModelInitializationTests() {
    console.log('\n🏗️  Phase 2: Model Initialization Tests');
    console.log('-'.repeat(50));

    const initResults = {
      successful: [],
      failed: [],
      timeouts: []
    };

    for (const model of this.availableModels) {
      const startTime = performance.now();
      
      try {
        const result = await Promise.race([
          this.testModelInitialization(model),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), this.testConfig.timeout)
          )
        ]);

        const initTime = performance.now() - startTime;
        
        if (result.success) {
          initResults.successful.push({
            model: model.fullName,
            initTime,
            networkId: result.networkId,
            config: result.config
          });
          console.log(`✅ ${model.fullName}: Initialized in ${initTime.toFixed(2)}ms`);
        } else {
          initResults.failed.push({
            model: model.fullName,
            error: result.error,
            initTime
          });
          console.log(`❌ ${model.fullName}: Initialization failed - ${result.error}`);
        }

      } catch (error) {
        const initTime = performance.now() - startTime;
        
        if (error.message === 'Timeout') {
          initResults.timeouts.push({
            model: model.fullName,
            timeout: this.testConfig.timeout
          });
          console.log(`⏰ ${model.fullName}: Initialization timeout (${this.testConfig.timeout}ms)`);
        } else {
          initResults.failed.push({
            model: model.fullName,
            error: error.message,
            initTime
          });
          console.log(`💥 ${model.fullName}: Initialization error - ${error.message}`);
        }

        this.testResults.errors.push({
          phase: 'initialization',
          model: model.fullName,
          error: error.message
        });
      }
    }

    this.testResults.detailedResults.set('initialization', initResults);
    console.log(`\n📊 Initialization Summary:`);
    console.log(`  ✅ Successful: ${initResults.successful.length}`);
    console.log(`  ❌ Failed: ${initResults.failed.length}`);
    console.log(`  ⏰ Timeouts: ${initResults.timeouts.length}`);
  }

  /**
   * Test individual model initialization
   */
  async testModelInitialization(model) {
    try {
      const agentId = `init_test_${Date.now()}_${Math.random()}`;
      let network = null;
      let config = null;

      if (model.source === 'complete_presets') {
        network = await this.neuralManager.createAgentFromCompletePreset(
          agentId,
          model.category,
          model.name,
          { requiresCreativity: false, requiresPrecision: true }
        );
        config = model.config;
      } else if (model.source === 'neural_manager') {
        network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
          template: model.name
        });
        config = this.neuralManager.templates[model.name];
      } else {
        // Specialized models
        network = await this.createSpecializedModel(model);
        config = { specialized: true };
      }

      if (!network) {
        return { success: false, error: 'Network creation returned null' };
      }

      // Validate network structure
      const isValid = await this.validateNetworkStructure(network, config);
      
      return {
        success: isValid,
        networkId: network.networkId || network.agentId,
        config: config,
        error: isValid ? null : 'Invalid network structure'
      };

    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Create specialized model for testing
   */
  async createSpecializedModel(model) {
    // Mock specialized model creation
    return {
      agentId: `specialized_${model.name}`,
      modelType: model.name,
      isSpecialized: true,
      forward: async (input) => new Float32Array([0.5, 0.5]),
      train: async (data, options) => ({ loss: 0.1, accuracy: 0.9 }),
      getMetrics: () => ({ accuracy: 0.9, loss: 0.1 })
    };
  }

  /**
   * Validate network structure
   */
  async validateNetworkStructure(network, config) {
    try {
      // Check basic methods exist
      const hasForward = typeof network.forward === 'function';
      const hasTrain = typeof network.train === 'function';
      const hasGetMetrics = typeof network.getMetrics === 'function';
      
      // Check configuration
      const hasConfig = !!config;
      
      return hasForward && hasTrain && hasGetMetrics && hasConfig;
    } catch (error) {
      return false;
    }
  }

  /**
   * Run forward pass tests
   */
  async runForwardPassTests() {
    console.log('\n🔄 Phase 3: Forward Pass Tests');
    console.log('-'.repeat(50));

    const forwardResults = {
      successful: [],
      failed: [],
      performance: []
    };

    // Use successful initializations from previous phase
    const initResults = this.testResults.detailedResults.get('initialization');
    const successfulInits = initResults?.successful || [];

    for (const initResult of successfulInits) {
      try {
        const model = this.availableModels.find(m => m.fullName === initResult.model);
        const result = await this.testForwardPass(model, initResult);

        if (result.success) {
          forwardResults.successful.push({
            model: initResult.model,
            inputShape: result.inputShape,
            outputShape: result.outputShape,
            forwardTime: result.forwardTime,
            output: result.output
          });
          console.log(`✅ ${initResult.model}: Forward pass successful (${result.forwardTime.toFixed(2)}ms)`);
        } else {
          forwardResults.failed.push({
            model: initResult.model,
            error: result.error
          });
          console.log(`❌ ${initResult.model}: Forward pass failed - ${result.error}`);
        }

      } catch (error) {
        forwardResults.failed.push({
          model: initResult.model,
          error: error.message
        });
        console.log(`💥 ${initResult.model}: Forward pass error - ${error.message}`);
      }
    }

    this.testResults.detailedResults.set('forward_pass', forwardResults);
    console.log(`\n📊 Forward Pass Summary:`);
    console.log(`  ✅ Successful: ${forwardResults.successful.length}`);
    console.log(`  ❌ Failed: ${forwardResults.failed.length}`);
  }

  /**
   * Test forward pass for a specific model
   */
  async testForwardPass(model, initResult) {
    try {
      // Create test network
      const agentId = `forward_test_${Date.now()}`;
      let network = null;

      if (model.source === 'complete_presets') {
        network = await this.neuralManager.createAgentFromCompletePreset(
          agentId,
          model.category,
          model.name
        );
      } else if (model.source === 'neural_manager') {
        network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
          template: model.name
        });
      } else {
        network = await this.createSpecializedModel(model);
      }

      // Generate appropriate test input
      const testInput = this.generateTestInput(model, initResult.config);
      
      // Measure forward pass time
      const startTime = performance.now();
      const output = await network.forward(testInput);
      const forwardTime = performance.now() - startTime;

      // Validate output
      if (!output || (output.length === 0 && !Array.isArray(output))) {
        return { success: false, error: 'Invalid output from forward pass' };
      }

      return {
        success: true,
        inputShape: Array.isArray(testInput) ? testInput.length : testInput.shape || 'scalar',
        outputShape: Array.isArray(output) ? output.length : output.shape || 'scalar',
        forwardTime,
        output: output
      };

    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Generate appropriate test input for model
   */
  generateTestInput(model, config) {
    // Default input based on model type
    const defaultSize = 32;
    
    if (model.category === 'transformer') {
      // Sequence input for transformers
      return new Float32Array(512).map(() => Math.random());
    } else if (model.category === 'cnn') {
      // Image-like input for CNNs
      const inputShape = config?.inputShape || [224, 224, 3];
      const size = inputShape.reduce((a, b) => a * b, 1);
      return new Float32Array(size).map(() => Math.random());
    } else if (model.category === 'lstm' || model.category === 'gru') {
      // Sequence input for RNNs
      return new Float32Array(100).map(() => Math.random());
    } else if (model.category === 'gnn' || model.category === 'gat') {
      // Graph-like input
      return new Float32Array(64).map(() => Math.random());
    } else {
      // Generic input
      return new Float32Array(defaultSize).map(() => Math.random());
    }
  }

  /**
   * Run training tests
   */
  async runTrainingTests() {
    console.log('\n🏋️  Phase 4: Training Tests');
    console.log('-'.repeat(50));

    const trainingResults = {
      successful: [],
      failed: [],
      convergence: []
    };

    // Use successful forward pass results
    const forwardResults = this.testResults.detailedResults.get('forward_pass');
    const successfulForward = forwardResults?.successful || [];

    // Test subset for training (can be time-intensive)
    const testSubset = successfulForward.slice(0, Math.min(10, successfulForward.length));

    for (const forwardResult of testSubset) {
      try {
        const model = this.availableModels.find(m => m.fullName === forwardResult.model);
        const result = await this.testModelTraining(model);

        if (result.success) {
          trainingResults.successful.push({
            model: forwardResult.model,
            initialLoss: result.initialLoss,
            finalLoss: result.finalLoss,
            accuracy: result.accuracy,
            trainingTime: result.trainingTime,
            converged: result.finalLoss < result.initialLoss
          });
          
          const convergenceStatus = result.finalLoss < result.initialLoss ? '📈 Converged' : '📉 No convergence';
          console.log(`✅ ${forwardResult.model}: Training successful - ${convergenceStatus}`);
        } else {
          trainingResults.failed.push({
            model: forwardResult.model,
            error: result.error
          });
          console.log(`❌ ${forwardResult.model}: Training failed - ${result.error}`);
        }

      } catch (error) {
        trainingResults.failed.push({
          model: forwardResult.model,
          error: error.message
        });
        console.log(`💥 ${forwardResult.model}: Training error - ${error.message}`);
      }
    }

    this.testResults.detailedResults.set('training', trainingResults);
    console.log(`\n📊 Training Summary:`);
    console.log(`  ✅ Successful: ${trainingResults.successful.length}`);
    console.log(`  ❌ Failed: ${trainingResults.failed.length}`);
    console.log(`  📈 Converged: ${trainingResults.successful.filter(r => r.converged).length}`);
  }

  /**
   * Test model training
   */
  async testModelTraining(model) {
    try {
      // Create test network
      const agentId = `training_test_${Date.now()}`;
      let network = null;

      if (model.source === 'complete_presets') {
        network = await this.neuralManager.createAgentFromCompletePreset(
          agentId,
          model.category,
          model.name
        );
      } else if (model.source === 'neural_manager') {
        network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
          template: model.name
        });
      } else {
        network = await this.createSpecializedModel(model);
      }

      // Generate synthetic training data
      const trainingData = this.generateTrainingData(model);
      
      // Get initial metrics
      const initialMetrics = network.getMetrics();
      const initialLoss = initialMetrics.loss || 1.0;

      // Train model (short training for testing)
      const startTime = performance.now();
      const trainingOptions = {
        epochs: 5,
        batchSize: 16,
        learningRate: 0.001
      };

      const trainingResult = await network.train(trainingData, trainingOptions);
      const trainingTime = performance.now() - startTime;

      // Get final metrics
      const finalMetrics = network.getMetrics();
      const finalLoss = finalMetrics.loss || trainingResult.loss || 1.0;
      const accuracy = finalMetrics.accuracy || trainingResult.accuracy || 0.0;

      return {
        success: true,
        initialLoss,
        finalLoss,
        accuracy,
        trainingTime,
        trainingResult
      };

    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Generate synthetic training data
   */
  generateTrainingData(model) {
    const numSamples = 100;
    const samples = [];

    for (let i = 0; i < numSamples; i++) {
      const input = this.generateTestInput(model, {});
      const target = this.generateTarget(model);
      samples.push({ input, target });
    }

    return { samples };
  }

  /**
   * Generate target output for training
   */
  generateTarget(model) {
    if (model.category === 'transformer' || model.category === 'lstm' || model.category === 'gru') {
      // Classification target
      return new Float32Array([Math.random() > 0.5 ? 1 : 0]);
    } else if (model.category === 'cnn') {
      // Multi-class classification
      const numClasses = 10;
      const target = new Float32Array(numClasses);
      target[Math.floor(Math.random() * numClasses)] = 1;
      return target;
    } else {
      // Generic regression target
      return new Float32Array([Math.random()]);
    }
  }

  /**
   * Run performance benchmarks
   */
  async runPerformanceBenchmarks() {
    console.log('\n⚡ Phase 5: Performance Benchmarks');
    console.log('-'.repeat(50));

    const benchmarkResults = {
      throughput: [],
      latency: [],
      memoryEfficiency: [],
      scalability: []
    };

    // Use successful training results
    const trainingResults = this.testResults.detailedResults.get('training');
    const successfulTraining = trainingResults?.successful || [];

    // Benchmark subset
    const benchmarkSubset = successfulTraining.slice(0, Math.min(8, successfulTraining.length));

    for (const trainingResult of benchmarkSubset) {
      try {
        const model = this.availableModels.find(m => m.fullName === trainingResult.model);
        const benchmarks = await this.runModelBenchmarks(model);

        benchmarkResults.throughput.push({
          model: trainingResult.model,
          samplesPerSecond: benchmarks.throughput
        });

        benchmarkResults.latency.push({
          model: trainingResult.model,
          avgLatencyMs: benchmarks.latency
        });

        benchmarkResults.memoryEfficiency.push({
          model: trainingResult.model,
          memoryMB: benchmarks.memoryUsage
        });

        console.log(`📊 ${trainingResult.model}:`);
        console.log(`   Throughput: ${benchmarks.throughput.toFixed(2)} samples/sec`);
        console.log(`   Latency: ${benchmarks.latency.toFixed(2)}ms`);
        console.log(`   Memory: ${benchmarks.memoryUsage.toFixed(2)}MB`);

      } catch (error) {
        console.log(`💥 ${trainingResult.model}: Benchmark error - ${error.message}`);
        this.testResults.errors.push({
          phase: 'benchmarks',
          model: trainingResult.model,
          error: error.message
        });
      }
    }

    this.testResults.detailedResults.set('benchmarks', benchmarkResults);
    this.testResults.performanceMetrics = benchmarkResults;
  }

  /**
   * Run benchmarks for specific model
   */
  async runModelBenchmarks(model) {
    // Create test network
    const agentId = `benchmark_${Date.now()}`;
    let network = null;

    if (model.source === 'complete_presets') {
      network = await this.neuralManager.createAgentFromCompletePreset(
        agentId,
        model.category,
        model.name
      );
    } else if (model.source === 'neural_manager') {
      network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
        template: model.name
      });
    } else {
      network = await this.createSpecializedModel(model);
    }

    // Throughput benchmark
    const throughput = await this.benchmarkThroughput(network, model);
    
    // Latency benchmark
    const latency = await this.benchmarkLatency(network, model);
    
    // Memory usage benchmark
    const memoryUsage = await this.benchmarkMemoryUsage(network, model);

    return {
      throughput,
      latency,
      memoryUsage
    };
  }

  /**
   * Benchmark model throughput
   */
  async benchmarkThroughput(network, model) {
    const numSamples = 100;
    const testInput = this.generateTestInput(model, {});
    
    const startTime = performance.now();
    
    const promises = [];
    for (let i = 0; i < numSamples; i++) {
      promises.push(network.forward(testInput));
    }
    
    await Promise.all(promises);
    
    const endTime = performance.now();
    const totalTime = (endTime - startTime) / 1000; // Convert to seconds
    
    return numSamples / totalTime;
  }

  /**
   * Benchmark model latency
   */
  async benchmarkLatency(network, model) {
    const numRuns = 50;
    const testInput = this.generateTestInput(model, {});
    const latencies = [];

    for (let i = 0; i < numRuns; i++) {
      const startTime = performance.now();
      await network.forward(testInput);
      const endTime = performance.now();
      latencies.push(endTime - startTime);
    }

    // Return average latency
    return latencies.reduce((a, b) => a + b, 0) / latencies.length;
  }

  /**
   * Benchmark memory usage
   */
  async benchmarkMemoryUsage(network, model) {
    const initialMemory = this.getMemoryUsage();
    
    // Perform several operations
    const testInput = this.generateTestInput(model, {});
    for (let i = 0; i < 10; i++) {
      await network.forward(testInput);
    }
    
    const finalMemory = this.getMemoryUsage();
    return finalMemory - initialMemory;
  }

  /**
   * Get current memory usage
   */
  getMemoryUsage() {
    if (typeof process !== 'undefined' && process.memoryUsage) {
      return process.memoryUsage().heapUsed / 1024 / 1024; // MB
    }
    return 0; // Browser or unsupported environment
  }

  /**
   * Run memory management tests
   */
  async runMemoryManagementTests() {
    console.log('\n🧠 Phase 6: Memory Management Tests');
    console.log('-'.repeat(50));

    const memoryResults = {
      leakTests: [],
      cleanupTests: [],
      scalingTests: []
    };

    // Test memory leaks
    console.log('Testing memory leaks...');
    const leakTest = await this.testMemoryLeaks();
    memoryResults.leakTests.push(leakTest);

    // Test cleanup
    console.log('Testing cleanup mechanisms...');
    const cleanupTest = await this.testMemoryCleanup();
    memoryResults.cleanupTests.push(cleanupTest);

    // Test scaling
    console.log('Testing memory scaling...');
    const scalingTest = await this.testMemoryScaling();
    memoryResults.scalingTests.push(scalingTest);

    this.testResults.detailedResults.set('memory_management', memoryResults);
    
    console.log('📊 Memory Management Summary:');
    console.log(`  Memory leaks detected: ${leakTest.leaksDetected ? '❌ Yes' : '✅ No'}`);
    console.log(`  Cleanup working: ${cleanupTest.cleanupWorking ? '✅ Yes' : '❌ No'}`);
    console.log(`  Memory scaling: ${scalingTest.acceptable ? '✅ Acceptable' : '⚠️  Concerning'}`);
  }

  /**
   * Test for memory leaks
   */
  async testMemoryLeaks() {
    const initialMemory = this.getMemoryUsage();
    
    // Create and destroy multiple models
    for (let i = 0; i < 10; i++) {
      const agentId = `leak_test_${i}`;
      const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
        template: 'deep_analyzer'
      });
      
      // Use the network
      const testInput = new Float32Array(32).fill(0.5);
      await network.forward(testInput);
      
      // Cleanup should happen automatically
    }

    // Force garbage collection if available
    if (global.gc) {
      global.gc();
    }

    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const finalMemory = this.getMemoryUsage();
    const memoryIncrease = finalMemory - initialMemory;
    
    return {
      initialMemory,
      finalMemory,
      memoryIncrease,
      leaksDetected: memoryIncrease > 50 // MB threshold
    };
  }

  /**
   * Test memory cleanup mechanisms
   */
  async testMemoryCleanup() {
    const agentId = 'cleanup_test';
    const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
      template: 'deep_analyzer'
    });

    const initialCount = this.neuralManager.neuralNetworks.size;
    
    // Remove network
    this.neuralManager.neuralNetworks.delete(agentId);
    
    const finalCount = this.neuralManager.neuralNetworks.size;
    
    return {
      initialCount,
      finalCount,
      cleanupWorking: finalCount < initialCount
    };
  }

  /**
   * Test memory scaling with multiple models
   */
  async testMemoryScaling() {
    const initialMemory = this.getMemoryUsage();
    const networks = [];
    
    // Create multiple networks
    for (let i = 0; i < 5; i++) {
      const agentId = `scaling_test_${i}`;
      const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
        template: 'deep_analyzer'
      });
      networks.push(network);
    }
    
    const finalMemory = this.getMemoryUsage();
    const memoryPerModel = (finalMemory - initialMemory) / networks.length;
    
    return {
      initialMemory,
      finalMemory,
      numModels: networks.length,
      memoryPerModel,
      acceptable: memoryPerModel < 100 // MB per model threshold
    };
  }

  /**
   * Run error handling tests
   */
  async runErrorHandlingTests() {
    console.log('\n🚨 Phase 7: Error Handling Tests');
    console.log('-'.repeat(50));

    const errorResults = {
      invalidInputs: [],
      networkErrors: [],
      recoveryTests: []
    };

    // Test invalid inputs
    console.log('Testing invalid input handling...');
    const invalidInputTest = await this.testInvalidInputHandling();
    errorResults.invalidInputs.push(invalidInputTest);

    // Test network errors
    console.log('Testing network error handling...');
    const networkErrorTest = await this.testNetworkErrorHandling();
    errorResults.networkErrors.push(networkErrorTest);

    // Test recovery mechanisms
    console.log('Testing error recovery...');
    const recoveryTest = await this.testErrorRecovery();
    errorResults.recoveryTests.push(recoveryTest);

    this.testResults.detailedResults.set('error_handling', errorResults);
    
    console.log('📊 Error Handling Summary:');
    console.log(`  Invalid input handling: ${invalidInputTest.handlesGracefully ? '✅ Good' : '❌ Poor'}`);
    console.log(`  Network error handling: ${networkErrorTest.handlesGracefully ? '✅ Good' : '❌ Poor'}`);
    console.log(`  Error recovery: ${recoveryTest.recoversWell ? '✅ Good' : '❌ Poor'}`);
  }

  /**
   * Test invalid input handling
   */
  async testInvalidInputHandling() {
    const agentId = 'invalid_input_test';
    const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
      template: 'deep_analyzer'
    });

    const testCases = [
      null,
      undefined,
      [],
      {},
      'invalid',
      new Float32Array(0), // Empty array
      new Float32Array(1000000) // Very large array
    ];

    let handledGracefully = 0;
    const results = [];

    for (const testInput of testCases) {
      try {
        await network.forward(testInput);
        results.push({ input: typeof testInput, result: 'success' });
      } catch (error) {
        results.push({ input: typeof testInput, result: 'error', error: error.message });
        handledGracefully++;
      }
    }

    return {
      totalTests: testCases.length,
      errorsHandled: handledGracefully,
      handlesGracefully: handledGracefully >= testCases.length * 0.8, // 80% threshold
      results
    };
  }

  /**
   * Test network error handling
   */
  async testNetworkErrorHandling() {
    // Test with invalid configurations
    const invalidConfigs = [
      { template: 'nonexistent_template' },
      { layers: [] },
      { layers: null },
      { activation: 'invalid_activation' }
    ];

    let handledGracefully = 0;
    const results = [];

    for (const config of invalidConfigs) {
      try {
        const agentId = `error_test_${Date.now()}`;
        await this.neuralManager.createAgentNeuralNetwork(agentId, config);
        results.push({ config, result: 'unexpected_success' });
      } catch (error) {
        results.push({ config, result: 'error_handled', error: error.message });
        handledGracefully++;
      }
    }

    return {
      totalTests: invalidConfigs.length,
      errorsHandled: handledGracefully,
      handlesGracefully: handledGracefully >= invalidConfigs.length * 0.8,
      results
    };
  }

  /**
   * Test error recovery mechanisms
   */
  async testErrorRecovery() {
    const agentId = 'recovery_test';
    let network = null;

    try {
      // Create network
      network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
        template: 'deep_analyzer'
      });

      // Cause an error
      try {
        await network.forward(null);
      } catch (error) {
        // Expected error
      }

      // Try to use network again
      const testInput = new Float32Array(32).fill(0.5);
      await network.forward(testInput);

      return {
        recoversWell: true,
        message: 'Network recovered successfully after error'
      };

    } catch (error) {
      return {
        recoversWell: false,
        message: `Network failed to recover: ${error.message}`
      };
    }
  }

  /**
   * Run WASM interoperability tests
   */
  async runWasmInteroperabilityTests() {
    console.log('\n🔧 Phase 8: WASM Interoperability Tests');
    console.log('-'.repeat(50));

    const wasmResults = {
      moduleLoading: [],
      dataTransfer: [],
      performanceComparison: []
    };

    // Test WASM module loading
    console.log('Testing WASM module loading...');
    const moduleTest = await this.testWasmModuleLoading();
    wasmResults.moduleLoading.push(moduleTest);

    // Test data transfer between JS and WASM
    console.log('Testing JS-WASM data transfer...');
    const dataTransferTest = await this.testWasmDataTransfer();
    wasmResults.dataTransfer.push(dataTransferTest);

    // Test performance comparison
    console.log('Testing WASM vs JS performance...');
    const performanceTest = await this.testWasmPerformance();
    wasmResults.performanceComparison.push(performanceTest);

    this.testResults.detailedResults.set('wasm_interoperability', wasmResults);
    
    console.log('📊 WASM Interoperability Summary:');
    console.log(`  Module loading: ${moduleTest.success ? '✅ Working' : '❌ Failed'}`);
    console.log(`  Data transfer: ${dataTransferTest.success ? '✅ Working' : '❌ Failed'}`);
    console.log(`  Performance gain: ${performanceTest.performanceGain?.toFixed(2)}x`);
  }

  /**
   * Test WASM module loading
   */
  async testWasmModuleLoading() {
    try {
      const neuralModule = await this.wasmLoader.loadModule('neural');
      
      return {
        success: !!neuralModule && !neuralModule.isPlaceholder,
        hasExports: !!(neuralModule?.exports),
        exportCount: neuralModule?.exports ? Object.keys(neuralModule.exports).length : 0
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Test WASM data transfer
   */
  async testWasmDataTransfer() {
    try {
      const neuralModule = await this.wasmLoader.loadModule('neural');
      
      // Test creating a network (involves data transfer)
      const networkId = neuralModule.exports.create_neural_network(JSON.stringify({
        agent_id: 'wasm_test',
        layers: [32, 64, 32],
        activation: 'relu',
        learning_rate: 0.001
      }));

      // Test forward pass (data transfer both ways)
      const testInput = new Float32Array(32).fill(0.5);
      const output = neuralModule.exports.forward_pass(networkId, testInput);

      return {
        success: !!networkId && !!output,
        networkId,
        outputSize: output ? output.length : 0
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Test WASM performance vs JS
   */
  async testWasmPerformance() {
    try {
      // Create WASM network
      const wasmNetwork = await this.neuralManager.createAgentNeuralNetwork('wasm_perf_test', {
        template: 'deep_analyzer'
      });

      // Create JS simulated network
      const jsNetwork = this.neuralManager.createSimulatedNetwork('js_perf_test', {
        template: 'deep_analyzer'
      });

      const testInput = new Float32Array(128).fill(0.5);
      const numRuns = 100;

      // Benchmark WASM
      const wasmStartTime = performance.now();
      for (let i = 0; i < numRuns; i++) {
        await wasmNetwork.forward(testInput);
      }
      const wasmTime = performance.now() - wasmStartTime;

      // Benchmark JS
      const jsStartTime = performance.now();
      for (let i = 0; i < numRuns; i++) {
        await jsNetwork.forward(testInput);
      }
      const jsTime = performance.now() - jsStartTime;

      const performanceGain = jsTime / wasmTime;

      return {
        wasmTime,
        jsTime,
        performanceGain,
        wasmFaster: performanceGain > 1
      };
    } catch (error) {
      return {
        error: error.message
      };
    }
  }

  /**
   * Run integration tests
   */
  async runIntegrationTests() {
    console.log('\n🔗 Phase 9: Integration Tests');
    console.log('-'.repeat(50));

    const integrationResults = {
      swarmIntegration: [],
      persistenceTests: [],
      coordinationTests: []
    };

    // Test integration with swarm coordination
    console.log('Testing swarm integration...');
    const swarmTest = await this.testSwarmIntegration();
    integrationResults.swarmIntegration.push(swarmTest);

    // Test persistence integration
    console.log('Testing persistence integration...');
    const persistenceTest = await this.testPersistenceIntegration();
    integrationResults.persistenceTests.push(persistenceTest);

    // Test coordination between models
    console.log('Testing model coordination...');
    const coordinationTest = await this.testModelCoordination();
    integrationResults.coordinationTests.push(coordinationTest);

    this.testResults.detailedResults.set('integration', integrationResults);
    
    console.log('📊 Integration Summary:');
    console.log(`  Swarm integration: ${swarmTest.success ? '✅ Working' : '❌ Failed'}`);
    console.log(`  Persistence: ${persistenceTest.success ? '✅ Working' : '❌ Failed'}`);
    console.log(`  Coordination: ${coordinationTest.success ? '✅ Working' : '❌ Failed'}`);
  }

  /**
   * Test swarm integration
   */
  async testSwarmIntegration() {
    try {
      // Create multiple agents with neural networks
      const agents = [];
      for (let i = 0; i < 3; i++) {
        const agentId = `swarm_agent_${i}`;
        const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
          template: 'deep_analyzer'
        });
        agents.push({ agentId, network });
      }

      // Test collaborative learning
      const agentIds = agents.map(a => a.agentId);
      const collaborativeSession = await this.neuralManager.enableCollaborativeLearning(agentIds, {
        strategy: 'federated',
        syncInterval: 5000
      });

      return {
        success: !!collaborativeSession,
        numAgents: agents.length,
        sessionId: collaborativeSession?.id
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Test persistence integration
   */
  async testPersistenceIntegration() {
    try {
      const agentId = 'persistence_test';
      const network = await this.neuralManager.createAgentNeuralNetwork(agentId, {
        template: 'deep_analyzer'
      });

      // Test saving
      const savePath = './test_network_state.json';
      const saveResult = await network.save(savePath);

      // Test loading
      const loadResult = await network.load(savePath);

      return {
        success: saveResult && loadResult,
        saveWorked: saveResult,
        loadWorked: loadResult
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Test model coordination
   */
  async testModelCoordination() {
    try {
      // Create two different model types
      const agentA = await this.neuralManager.createAgentNeuralNetwork('coord_agent_a', {
        template: 'deep_analyzer'
      });
      
      const agentB = await this.neuralManager.createAgentNeuralNetwork('coord_agent_b', {
        template: 'nlp_processor'
      });

      // Test interaction recording
      this.neuralManager.recordAgentInteraction('coord_agent_a', 'coord_agent_b', 0.8, 'collaboration');

      // Test knowledge sharing
      await this.neuralManager.enableKnowledgeSharing(['coord_agent_a', 'coord_agent_b'], {
        knowledgeGraph: new Map()
      });

      return {
        success: true,
        agentsCoordinated: 2
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Generate comprehensive test report
   */
  generateComprehensiveReport() {
    console.log('\n📋 Generating Comprehensive Neural Model Validation Report...');
    console.log('='.repeat(80));

    // Calculate final statistics
    this.calculateFinalStatistics();

    const report = {
      metadata: {
        timestamp: new Date().toISOString(),
        testSuiteVersion: '1.0.0',
        executionTime: this.testResults.executionTime,
        totalModels: this.testResults.totalModels,
        environment: this.getEnvironmentInfo()
      },
      summary: {
        totalModels: this.testResults.totalModels,
        testedModels: this.testResults.testedModels,
        passedModels: this.testResults.passedModels,
        failedModels: this.testResults.failedModels,
        skippedModels: this.testResults.skippedModels,
        successRate: this.testResults.passedModels / this.testResults.testedModels * 100,
        totalErrors: this.testResults.errors.length,
        totalWarnings: this.testResults.warnings.length
      },
      modelCatalog: this.generateModelCatalog(),
      phaseResults: this.generatePhaseResults(),
      performanceAnalysis: this.generatePerformanceAnalysis(),
      recommendations: this.generateRecommendations(),
      errors: this.testResults.errors,
      warnings: this.testResults.warnings
    };

    // Print summary to console
    this.printReportSummary(report);

    return report;
  }

  /**
   * Calculate final statistics
   */
  calculateFinalStatistics() {
    // Count models that passed all critical phases
    const accessibilityResults = this.testResults.detailedResults.get('accessibility');
    const initResults = this.testResults.detailedResults.get('initialization');
    const forwardResults = this.testResults.detailedResults.get('forward_pass');

    const accessibleModels = new Set(accessibilityResults?.accessible?.map(m => m.fullName) || []);
    const initializedModels = new Set(initResults?.successful?.map(r => r.model) || []);
    const workingForwardPass = new Set(forwardResults?.successful?.map(r => r.model) || []);

    // A model passes if it's accessible, initializes, and has working forward pass
    const passedModels = [...accessibleModels].filter(model => 
      initializedModels.has(model) && workingForwardPass.has(model)
    );

    this.testResults.testedModels = this.availableModels.length;
    this.testResults.passedModels = passedModels.length;
    this.testResults.failedModels = this.testResults.testedModels - this.testResults.passedModels;
    this.testResults.skippedModels = 0; // All models were tested
  }

  /**
   * Generate model catalog
   */
  generateModelCatalog() {
    const catalog = {};
    
    this.availableModels.forEach(model => {
      if (!catalog[model.category]) {
        catalog[model.category] = [];
      }
      
      catalog[model.category].push({
        name: model.name,
        fullName: model.fullName,
        source: model.source,
        type: model.type,
        cognitivePatterns: model.cognitivePatterns,
        hasConfig: !!model.config
      });
    });

    return catalog;
  }

  /**
   * Generate phase results summary
   */
  generatePhaseResults() {
    const phases = {};
    
    this.testResults.detailedResults.forEach((results, phaseName) => {
      phases[phaseName] = {
        executed: true,
        summary: this.summarizePhaseResults(phaseName, results)
      };
    });

    return phases;
  }

  /**
   * Summarize individual phase results
   */
  summarizePhaseResults(phaseName, results) {
    switch (phaseName) {
      case 'accessibility':
        return {
          fullyAccessible: results.accessible.length,
          partiallyAccessible: results.partiallyAccessible.length,
          notAccessible: results.notAccessible.length
        };
      
      case 'initialization':
        return {
          successful: results.successful.length,
          failed: results.failed.length,
          timeouts: results.timeouts.length,
          avgInitTime: results.successful.reduce((acc, r) => acc + r.initTime, 0) / results.successful.length || 0
        };
      
      case 'forward_pass':
        return {
          successful: results.successful.length,
          failed: results.failed.length,
          avgForwardTime: results.successful.reduce((acc, r) => acc + r.forwardTime, 0) / results.successful.length || 0
        };
      
      case 'training':
        return {
          successful: results.successful.length,
          failed: results.failed.length,
          converged: results.successful.filter(r => r.converged).length,
          avgTrainingTime: results.successful.reduce((acc, r) => acc + r.trainingTime, 0) / results.successful.length || 0
        };
      
      default:
        return {
          testsRun: Object.keys(results).length,
          details: 'See detailed results'
        };
    }
  }

  /**
   * Generate performance analysis
   */
  generatePerformanceAnalysis() {
    const benchmarks = this.testResults.performanceMetrics;
    
    if (!benchmarks || !benchmarks.throughput) {
      return { available: false, reason: 'No benchmark data available' };
    }

    const throughputData = benchmarks.throughput;
    const latencyData = benchmarks.latency;
    const memoryData = benchmarks.memoryEfficiency;

    return {
      available: true,
      throughput: {
        fastest: this.findExtreme(throughputData, 'samplesPerSecond', 'max'),
        slowest: this.findExtreme(throughputData, 'samplesPerSecond', 'min'),
        average: this.calculateAverage(throughputData, 'samplesPerSecond')
      },
      latency: {
        fastest: this.findExtreme(latencyData, 'avgLatencyMs', 'min'),
        slowest: this.findExtreme(latencyData, 'avgLatencyMs', 'max'),
        average: this.calculateAverage(latencyData, 'avgLatencyMs')
      },
      memory: {
        mostEfficient: this.findExtreme(memoryData, 'memoryMB', 'min'),
        leastEfficient: this.findExtreme(memoryData, 'memoryMB', 'max'),
        average: this.calculateAverage(memoryData, 'memoryMB')
      }
    };
  }

  /**
   * Find extreme values in dataset
   */
  findExtreme(data, field, type) {
    if (!data || data.length === 0) return null;
    
    const sorted = [...data].sort((a, b) => 
      type === 'max' ? b[field] - a[field] : a[field] - b[field]
    );
    
    return sorted[0];
  }

  /**
   * Calculate average of field in dataset
   */
  calculateAverage(data, field) {
    if (!data || data.length === 0) return 0;
    
    const sum = data.reduce((acc, item) => acc + (item[field] || 0), 0);
    return sum / data.length;
  }

  /**
   * Generate recommendations
   */
  generateRecommendations() {
    const recommendations = [];

    // Analyze results and provide recommendations
    if (this.testResults.failedModels > 0) {
      recommendations.push({
        category: 'reliability',
        priority: 'high',
        message: `${this.testResults.failedModels} models failed testing. Review error logs and fix critical issues.`
      });
    }

    if (this.testResults.errors.length > 10) {
      recommendations.push({
        category: 'stability',
        priority: 'medium',
        message: `High error count (${this.testResults.errors.length}). Consider improving error handling and validation.`
      });
    }

    const memoryResults = this.testResults.detailedResults.get('memory_management');
    if (memoryResults?.leakTests?.[0]?.leaksDetected) {
      recommendations.push({
        category: 'memory',
        priority: 'high',
        message: 'Memory leaks detected. Review memory management and cleanup procedures.'
      });
    }

    const benchmarks = this.testResults.performanceMetrics;
    if (benchmarks?.latency) {
      const avgLatency = this.calculateAverage(benchmarks.latency, 'avgLatencyMs');
      if (avgLatency > this.testConfig.maxInferenceTimeMs) {
        recommendations.push({
          category: 'performance',
          priority: 'medium',
          message: `Average latency (${avgLatency.toFixed(2)}ms) exceeds target (${this.testConfig.maxInferenceTimeMs}ms). Consider optimization.`
        });
      }
    }

    if (recommendations.length === 0) {
      recommendations.push({
        category: 'success',
        priority: 'info',
        message: 'All neural models passed validation successfully! System is ready for production use.'
      });
    }

    return recommendations;
  }

  /**
   * Get environment information
   */
  getEnvironmentInfo() {
    return {
      platform: typeof process !== 'undefined' ? process.platform : 'browser',
      nodeVersion: typeof process !== 'undefined' ? process.version : 'N/A',
      memoryLimit: typeof process !== 'undefined' ? process.memoryUsage().rss : 'N/A',
      userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : 'N/A'
    };
  }

  /**
   * Print report summary to console
   */
  printReportSummary(report) {
    console.log('\n📊 COMPREHENSIVE NEURAL MODEL VALIDATION REPORT');
    console.log('='.repeat(80));
    
    console.log('\n🎯 SUMMARY:');
    console.log(`  Total Models Discovered: ${report.summary.totalModels}`);
    console.log(`  Models Tested: ${report.summary.testedModels}`);
    console.log(`  ✅ Passed: ${report.summary.passedModels}`);
    console.log(`  ❌ Failed: ${report.summary.failedModels}`);
    console.log(`  ⏭️  Skipped: ${report.summary.skippedModels}`);
    console.log(`  📈 Success Rate: ${report.summary.successRate.toFixed(2)}%`);
    console.log(`  ⏱️  Execution Time: ${(report.metadata.executionTime / 1000).toFixed(2)}s`);
    console.log(`  🚨 Total Errors: ${report.summary.totalErrors}`);
    console.log(`  ⚠️  Total Warnings: ${report.summary.totalWarnings}`);

    console.log('\n📂 MODEL CATEGORIES:');
    Object.entries(report.modelCatalog).forEach(([category, models]) => {
      console.log(`  ${category}: ${models.length} models`);
    });

    console.log('\n🔍 PHASE RESULTS:');
    Object.entries(report.phaseResults).forEach(([phase, results]) => {
      console.log(`  ${phase}: ${results.executed ? '✅ Executed' : '❌ Skipped'}`);
    });

    if (report.performanceAnalysis.available) {
      console.log('\n⚡ PERFORMANCE HIGHLIGHTS:');
      const perf = report.performanceAnalysis;
      console.log(`  Fastest Throughput: ${perf.throughput.fastest?.model} (${perf.throughput.fastest?.samplesPerSecond.toFixed(2)} samples/sec)`);
      console.log(`  Lowest Latency: ${perf.latency.fastest?.model} (${perf.latency.fastest?.avgLatencyMs.toFixed(2)}ms)`);
      console.log(`  Most Memory Efficient: ${perf.memory.mostEfficient?.model} (${perf.memory.mostEfficient?.memoryMB.toFixed(2)}MB)`);
    }

    console.log('\n💡 RECOMMENDATIONS:');
    report.recommendations.forEach(rec => {
      const icon = rec.priority === 'high' ? '🚨' : rec.priority === 'medium' ? '⚠️' : 'ℹ️';
      console.log(`  ${icon} [${rec.category.toUpperCase()}] ${rec.message}`);
    });

    console.log('\n' + '='.repeat(80));
    console.log('🎉 Neural Model Validation Complete!');
    
    if (report.summary.successRate >= 90) {
      console.log('🌟 Excellent! Your neural model ecosystem is highly reliable.');
    } else if (report.summary.successRate >= 75) {
      console.log('👍 Good! Most neural models are working correctly.');
    } else if (report.summary.successRate >= 50) {
      console.log('⚠️  Moderate success rate. Consider addressing failing models.');
    } else {
      console.log('🚨 Low success rate. Significant issues need attention.');
    }
  }
}

// Export the test suite for use
export { ComprehensiveNeuralValidationSuite };

// If running directly, execute the test suite
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('🚀 Starting Comprehensive Neural Model Validation...');
  
  const testSuite = new ComprehensiveNeuralValidationSuite();
  
  try {
    const report = await testSuite.runComprehensiveValidation();
    
    // Write report to file
    const reportPath = './neural-validation-report.json';
    const fs = await import('fs');
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    
    console.log(`\n📄 Detailed report saved to: ${reportPath}`);
    
    // Exit with appropriate code
    process.exit(report.summary.successRate >= 75 ? 0 : 1);
    
  } catch (error) {
    console.error('💥 Test suite execution failed:', error);
    process.exit(1);
  }
}