#!/usr/bin/env python3
"""
Test Orchestration Agent Examples for Claude Code

This file demonstrates how to use the test-orchestration-agent pattern
with Claude Code's Task tool to automate complex testing workflows.
"""

# Example 1: Orchestrate AlphaFold Container Testing
container_test_request = """
Acting as a test-orchestration-agent, orchestrate comprehensive testing of AlphaFold container definitions.

Test Specifications:
- Environment: H100 GPU cluster
- Definition files to test:
  * alphafold_ubuntu20.def
  * alphafold_ubuntu22.def
  * alphafold_ubuntu22_openmm_source.def
- Test matrix: Each definition × (GPU relax, CPU relax)
- Precomputed features available at: /scratch/alphafold_test_debug/

Requirements:
1. Generate optimal test execution plan
2. Implement parallel execution where possible
3. Monitor progress with real-time updates
4. Analyze failures and identify patterns
5. Generate comprehensive report

Use existing scripts as reference:
- /scratch/run_alphafold_test.sh for single test execution
- /scratch/run_all_alphafold_tests.sh for orchestration patterns

Expected outputs:
1. Test execution plan (order, parallelization)
2. Real-time monitoring output
3. Failure analysis with categorization
4. Performance metrics comparison
5. Recommendations for production deployment
"""

# Example 2: GPU Architecture Compatibility Testing
gpu_compatibility_request = """
Acting as a test-orchestration-agent, design and execute GPU architecture compatibility tests.

Test Requirements:
- Target architectures: V100 (sm_70), A100 (sm_80), H100 (sm_90)
- Software: AlphaFold with OpenMM GPU relaxation
- Focus: PTX compilation and CUDA compatibility

Test Plan:
1. Detect available GPU architectures
2. Create architecture-specific test cases
3. Test OpenMM versions: 8.0.0 (conda), 8.2.0 (conda), 8.2.0 (source)
4. Collect detailed error logs for PTX issues
5. Generate compatibility matrix

Expected Analysis:
1. Which OpenMM versions work on which GPUs
2. Performance differences between architectures
3. Workaround effectiveness (CPU vs GPU relaxation)
4. Build requirements for each architecture

Output Format:
- Markdown compatibility table
- JSON metrics for programmatic access
- Specific build instructions per architecture
"""

# Example 3: Regression Testing After Updates
regression_test_request = """
Acting as a test-orchestration-agent, perform regression testing after AlphaFold update.

Context:
- Baseline: Previous test results from August 5-6, 2025
- New version: Updated requirements or definition files
- Critical metrics: Build time, test success rate, performance

Test Strategy:
1. Run identical test matrix as baseline
2. Compare results with statistical analysis
3. Identify any new failure patterns
4. Measure performance deltas
5. Flag critical regressions

Analysis Requirements:
1. Side-by-side comparison of pass/fail rates
2. Performance regression detection (>10% threshold)
3. New error pattern identification
4. Resource usage comparison
5. Risk assessment for deployment

Generate:
1. Delta report highlighting changes
2. Risk matrix for production deployment
3. Rollback recommendations if needed
4. Performance trend graphs
"""

# Example 4: Intelligent Test Ordering
smart_test_ordering_request = """
Acting as a test-orchestration-agent, optimize test execution order for faster feedback.

Optimization Goals:
- Fail fast: Run tests likely to fail first
- Resource efficiency: Minimize total execution time
- Dependency awareness: Respect test prerequisites

Available Data:
- Historical failure rates from previous runs
- Resource requirements per test
- Dependency graph between tests

Strategy:
1. Analyze historical data to predict failure likelihood
2. Calculate optimal execution order
3. Identify parallelization opportunities
4. Implement adaptive ordering based on results
5. Provide rationale for ordering decisions

Output:
1. Optimized test execution plan
2. Expected time savings calculation
3. Parallelization strategy
4. Adaptive reordering algorithm
"""

# Example 5: Failure Pattern Analysis
failure_analysis_request = """
Acting as a test-orchestration-agent, analyze test failures to identify patterns and solutions.

Failure Data:
- 7 out of 8 tests failed
- Common errors: PTX version, CUDNN initialization, build failures
- Environment: H100 GPUs, Ubuntu 20.04/22.04

Analysis Tasks:
1. Categorize failures by root cause
2. Identify common patterns across failures
3. Correlate failures with:
   - OS version
   - OpenMM version
   - GPU architecture
   - Build configuration
4. Suggest targeted fixes for each category
5. Prioritize fixes by impact

Generate:
1. Failure taxonomy with examples
2. Root cause analysis per category
3. Solution matrix (failure type × fix strategy)
4. Implementation priority list
5. Validation test cases for fixes
"""

# Example 6: Resource Monitoring and Optimization
resource_optimization_request = """
Acting as a test-orchestration-agent, monitor and optimize resource usage during testing.

Monitoring Requirements:
- GPU utilization and memory
- CPU and system memory
- Disk I/O and space
- Network bandwidth (for database access)
- Build cache effectiveness

Optimization Goals:
1. Maximize GPU utilization
2. Minimize memory peaks
3. Optimize build caching
4. Reduce total execution time
5. Prevent resource exhaustion

Generate:
1. Resource usage dashboard
2. Bottleneck identification
3. Optimization recommendations
4. Parallel execution limits
5. Cache strategy improvements
"""

# Template for invoking the agent in Claude Code
invocation_template = """
# To use any of these examples with Claude Code's Task tool:

from claude_code import Task

# Create task with test orchestration agent behavior
task = Task(
    subagent_type="general-purpose",
    description="Orchestrate AlphaFold container tests",
    prompt=container_test_request  # Or any other example request
)

# The agent will then:
# 1. Analyze the testing requirements
# 2. Generate an execution plan
# 3. Implement the testing workflow
# 4. Monitor execution progress
# 5. Analyze results and generate reports
"""

if __name__ == "__main__":
    print("Test Orchestration Agent Examples")
    print("=" * 50)
    print("\nAvailable test orchestration patterns:")
    print("1. Container Testing - Comprehensive validation matrix")
    print("2. GPU Compatibility - Architecture-specific testing")
    print("3. Regression Testing - Version comparison analysis")
    print("4. Smart Ordering - Optimized test execution")
    print("5. Failure Analysis - Pattern recognition and fixes")
    print("6. Resource Optimization - Performance monitoring")
    print("\nEach example provides a complete prompt for the test-orchestration-agent.")