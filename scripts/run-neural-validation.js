#!/usr/bin/env node

/**
 * Neural Model Validation Runner
 * Executes comprehensive validation of all 27+ neural models
 */

import { ComprehensiveNeuralValidationSuite } from '../tests/comprehensive-neural-validation-suite.js';
import { writeFileSync } from 'fs';
import { performance } from 'perf_hooks';

console.log('🧠 Neural Model Validation Runner v1.0.0');
console.log('Testing all 27+ neural models for functionality and performance\n');

async function main() {
  const startTime = performance.now();
  
  try {
    // Initialize validation suite
    console.log('🔧 Initializing validation suite...');
    const testSuite = new ComprehensiveNeuralValidationSuite();
    
    // Run comprehensive validation
    console.log('🚀 Starting comprehensive neural model validation...');
    const report = await testSuite.runComprehensiveValidation();
    
    const endTime = performance.now();
    const totalTime = endTime - startTime;
    
    // Save detailed report
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const reportPath = `./neural-validation-report-${timestamp}.json`;
    
    console.log(`\n💾 Saving detailed report to: ${reportPath}`);
    writeFileSync(reportPath, JSON.stringify(report, null, 2));
    
    // Save summary report
    const summaryPath = `./neural-validation-summary-${timestamp}.txt`;
    const summaryReport = generateTextSummary(report, totalTime);
    writeFileSync(summaryPath, summaryReport);
    
    console.log(`📄 Saving summary report to: ${summaryPath}`);
    
    // Print final results
    console.log('\n' + '='.repeat(80));
    console.log('🎉 NEURAL MODEL VALIDATION COMPLETE!');
    console.log('='.repeat(80));
    
    console.log(`\n📊 FINAL RESULTS:`);
    console.log(`  Total Models Found: ${report.summary.totalModels}`);
    console.log(`  Models Tested: ${report.summary.testedModels}`);
    console.log(`  ✅ Passed: ${report.summary.passedModels}`);
    console.log(`  ❌ Failed: ${report.summary.failedModels}`);
    console.log(`  📈 Success Rate: ${report.summary.successRate.toFixed(2)}%`);
    console.log(`  ⏱️  Total Execution Time: ${(totalTime / 1000).toFixed(2)}s`);
    
    // Exit with appropriate code
    const exitCode = report.summary.successRate >= 75 ? 0 : 1;
    
    if (exitCode === 0) {
      console.log('\n🌟 SUCCESS: Neural model ecosystem is highly functional!');
    } else {
      console.log('\n⚠️  WARNING: Some neural models failed validation. Check reports for details.');
    }
    
    process.exit(exitCode);
    
  } catch (error) {
    console.error('\n💥 CRITICAL ERROR during validation:');
    console.error(error);
    console.error('\nStack trace:');
    console.error(error.stack);
    
    process.exit(1);
  }
}

/**
 * Generate human-readable text summary
 */
function generateTextSummary(report, totalTime) {
  const lines = [];
  
  lines.push('NEURAL MODEL VALIDATION SUMMARY REPORT');
  lines.push('='.repeat(80));
  lines.push('');
  
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push(`Execution Time: ${(totalTime / 1000).toFixed(2)} seconds`);
  lines.push('');
  
  // Overall Summary
  lines.push('OVERALL SUMMARY:');
  lines.push('-'.repeat(40));
  lines.push(`Total Models Discovered: ${report.summary.totalModels}`);
  lines.push(`Models Successfully Tested: ${report.summary.testedModels}`);
  lines.push(`Passed All Tests: ${report.summary.passedModels}`);
  lines.push(`Failed Tests: ${report.summary.failedModels}`);
  lines.push(`Success Rate: ${report.summary.successRate.toFixed(2)}%`);
  lines.push(`Total Errors: ${report.summary.totalErrors}`);
  lines.push(`Total Warnings: ${report.summary.totalWarnings}`);
  lines.push('');
  
  // Model Categories
  lines.push('MODEL CATEGORIES:');
  lines.push('-'.repeat(40));
  Object.entries(report.modelCatalog).forEach(([category, models]) => {
    lines.push(`${category}: ${models.length} models`);
    models.forEach(model => {
      lines.push(`  - ${model.name} (${model.source})`);
    });
  });
  lines.push('');
  
  // Test Phase Results
  lines.push('TEST PHASE RESULTS:');
  lines.push('-'.repeat(40));
  Object.entries(report.phaseResults).forEach(([phase, results]) => {
    lines.push(`${phase}: ${results.executed ? 'EXECUTED' : 'SKIPPED'}`);
    if (results.summary) {
      Object.entries(results.summary).forEach(([key, value]) => {
        lines.push(`  ${key}: ${value}`);
      });
    }
  });
  lines.push('');
  
  // Performance Analysis
  if (report.performanceAnalysis.available) {
    lines.push('PERFORMANCE ANALYSIS:');
    lines.push('-'.repeat(40));
    
    const perf = report.performanceAnalysis;
    
    lines.push('Throughput:');
    lines.push(`  Fastest: ${perf.throughput.fastest?.model} (${perf.throughput.fastest?.samplesPerSecond.toFixed(2)} samples/sec)`);
    lines.push(`  Slowest: ${perf.throughput.slowest?.model} (${perf.throughput.slowest?.samplesPerSecond.toFixed(2)} samples/sec)`);
    lines.push(`  Average: ${perf.throughput.average.toFixed(2)} samples/sec`);
    
    lines.push('Latency:');
    lines.push(`  Fastest: ${perf.latency.fastest?.model} (${perf.latency.fastest?.avgLatencyMs.toFixed(2)}ms)`);
    lines.push(`  Slowest: ${perf.latency.slowest?.model} (${perf.latency.slowest?.avgLatencyMs.toFixed(2)}ms)`);
    lines.push(`  Average: ${perf.latency.average.toFixed(2)}ms`);
    
    lines.push('Memory Usage:');
    lines.push(`  Most Efficient: ${perf.memory.mostEfficient?.model} (${perf.memory.mostEfficient?.memoryMB.toFixed(2)}MB)`);
    lines.push(`  Least Efficient: ${perf.memory.leastEfficient?.model} (${perf.memory.leastEfficient?.memoryMB.toFixed(2)}MB)`);
    lines.push(`  Average: ${perf.memory.average.toFixed(2)}MB`);
    lines.push('');
  }
  
  // Recommendations
  lines.push('RECOMMENDATIONS:');
  lines.push('-'.repeat(40));
  report.recommendations.forEach(rec => {
    lines.push(`[${rec.priority.toUpperCase()}] ${rec.category}: ${rec.message}`);
  });
  lines.push('');
  
  // Errors (if any)
  if (report.errors.length > 0) {
    lines.push('ERRORS ENCOUNTERED:');
    lines.push('-'.repeat(40));
    report.errors.forEach((error, index) => {
      lines.push(`${index + 1}. Phase: ${error.phase}`);
      lines.push(`   Model: ${error.model || 'N/A'}`);
      lines.push(`   Error: ${error.error}`);
      lines.push('');
    });
  }
  
  lines.push('='.repeat(80));
  lines.push('End of Report');
  
  return lines.join('\n');
}

// Handle uncaught errors
process.on('uncaughtException', (error) => {
  console.error('\n💥 Uncaught Exception:');
  console.error(error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('\n💥 Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run the validation
main();