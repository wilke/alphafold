# Test Orchestration Agent for Claude Code

## Agent Description

**test-orchestration-agent**: Use this agent to manage complex test matrices with multiple configurations and parameters. The agent handles test planning, execution, monitoring, result analysis, and generates comprehensive reports with performance metrics and failure patterns.

## Agent Capabilities

### 1. Test Matrix Generation
- Create comprehensive test plans from specifications
- Generate parameterized test configurations
- Identify optimal test ordering for faster failure detection
- Support for dependency-based test sequencing

### 2. Parallel Execution Management
- Orchestrate concurrent test execution
- Resource allocation and scheduling
- Progress monitoring and status updates
- Automatic retry logic for transient failures

### 3. Result Analysis and Reporting
- Aggregate results across test runs
- Pattern recognition for common failures
- Performance metric collection and analysis
- Generate both human-readable and machine-parseable reports

### 4. Failure Pattern Recognition
- Identify recurring error patterns
- Categorize failures by type and severity
- Suggest fixes based on historical data
- Track regression patterns across versions

## Usage Examples

### Example 1: Container Build Test Matrix
```
Task: Orchestrate testing of multiple AlphaFold container definitions

The agent will:
1. Analyze available definition files and configurations
2. Generate optimal test matrix (OS versions, GPU modes, OpenMM versions)
3. Execute tests in parallel where possible
4. Monitor progress and provide real-time updates
5. Analyze failures and identify patterns
6. Generate comprehensive report with recommendations
```

### Example 2: Hardware Compatibility Testing
```
Task: Test AlphaFold across different GPU architectures

The agent will:
1. Detect available hardware configurations
2. Create architecture-specific test plans
3. Handle architecture-specific error patterns (e.g., PTX errors)
4. Compare performance across architectures
5. Generate compatibility matrix
```

### Example 3: Regression Testing
```
Task: Validate new AlphaFold version against test suite

The agent will:
1. Compare with baseline test results
2. Identify performance regressions
3. Detect new failure patterns
4. Prioritize critical test failures
5. Generate delta report
```

## Implementation Pattern for Claude Code

When implementing this agent, use the following pattern:

```python
# Example test orchestration request
test_orchestration_request = """
Acting as a test-orchestration-agent, manage the testing of AlphaFold container definitions.

Test Requirements:
- Definition files: [list of .def files to test]
- Test configurations: GPU/CPU relaxation modes
- Hardware: H100 GPU environment
- Success criteria: Build completes, AlphaFold runs, correct output generated

Generate and execute:
1. Comprehensive test matrix
2. Execution plan with parallelization strategy
3. Monitoring dashboard
4. Result analysis with failure categorization
5. Final report with recommendations

Use patterns from:
- /scratch/run_alphafold_test.sh (parameterized test runner)
- /scratch/run_all_alphafold_tests.sh (orchestration example)
- Previous test results for baseline comparison
"""
```

## Test Matrix Template

```yaml
# test_matrix.yaml
test_suite:
  name: "AlphaFold Container Validation"
  
  parameters:
    definition_files:
      - alphafold_ubuntu20.def
      - alphafold_ubuntu22.def
      - alphafold_ubuntu22_openmm_source.def
    
    configurations:
      - name: "gpu_relax"
        use_gpu_relax: true
        expected_result: "success|ptx_error|cuda_error"
      
      - name: "cpu_relax"
        use_gpu_relax: false
        expected_result: "success"
    
    hardware:
      - gpu: "H100"
        compute_capability: "9.0"
        known_issues: ["OpenMM PTX compatibility"]
  
  execution:
    parallel_builds: 2
    parallel_tests: 4
    timeout_minutes: 60
    retry_on_transient: true
  
  reporting:
    formats: ["markdown", "json", "junit"]
    metrics: ["build_time", "test_time", "gpu_utilization", "memory_usage"]
```

## Error Pattern Database

```yaml
# error_patterns.yaml
patterns:
  - id: "ptx_version_error"
    regex: "CUDA_ERROR_UNSUPPORTED_PTX_VERSION.*222"
    category: "gpu_compatibility"
    severity: "high"
    affected_components: ["OpenMM", "GPU relaxation"]
    solution: "Use CPU relaxation or build OpenMM from source"
    
  - id: "cudnn_init_failed"
    regex: "Could not create cudnn handle.*CUDNN_STATUS_NOT_INITIALIZED"
    category: "library_compatibility"
    severity: "high"
    affected_components: ["JAX", "TensorFlow"]
    solution: "Install CUDNN dev packages, create proper symlinks"
    
  - id: "held_packages"
    regex: "Held packages were changed and -y was used"
    category: "build_error"
    severity: "medium"
    affected_components: ["apt-get"]
    solution: "Add --allow-change-held-packages flag"
```

## Monitoring Dashboard Template

```
===============================================
AlphaFold Test Suite Execution Monitor
===============================================
Start Time: 2025-08-06 08:00:00
Elapsed: 02:35:42

Test Progress:
[████████████████████░░░░░░] 6/8 (75%)

Current Status:
✓ ubuntu20_base_cpu      - PASSED (32m)
✗ ubuntu22_base_gpu      - FAILED (PTX error)
✓ ubuntu20_base_gpu      - FAILED (Expected)
⚡ ubuntu22_source_gpu    - RUNNING (15m)
⏸ ubuntu22_openmm81_cpu  - QUEUED
⏸ ubuntu22_openmm82_cpu  - QUEUED

Resource Utilization:
GPU: [████████░░] 80% | Memory: [██████░░░░] 60%
Disk: 145GB used | Network: Minimal

Recent Errors:
[10:15:32] ubuntu22_base_gpu: CUDA_ERROR_UNSUPPORTED_PTX_VERSION
[10:18:45] Build warning: Package conflicts detected

Next Action: Analyzing failure patterns...
===============================================
```

## Result Aggregation

```python
# Example result structure
test_results = {
    "summary": {
        "total_tests": 8,
        "passed": 1,
        "failed": 7,
        "duration_seconds": 9342,
        "test_date": "2025-08-06"
    },
    "tests": [
        {
            "name": "ubuntu20_base_cpu",
            "status": "passed",
            "build_time": 388,
            "test_time": 1927,
            "errors": [],
            "metrics": {
                "gpu_utilization": 0,
                "peak_memory_gb": 45.2
            }
        }
    ],
    "patterns": {
        "ptx_errors": 2,
        "cudnn_errors": 3,
        "build_failures": 2
    },
    "recommendations": [
        "Use CPU relaxation for H100 systems",
        "Ubuntu 20.04 shows better stability",
        "Consider OpenMM source builds for H100"
    ]
}
```

## Integration with CI/CD

```yaml
# .github/workflows/alphafold-test.yml
name: AlphaFold Container Test Suite

on:
  push:
    paths:
      - 'docker/*.def'
      - 'alphafold/*.def'

jobs:
  test-orchestration:
    runs-on: [self-hosted, gpu]
    steps:
      - name: Run Test Orchestration Agent
        run: |
          claude-code-agent test-orchestration \
            --config test_matrix.yaml \
            --output-dir ./test-results \
            --parallel 4
```

## Best Practices

1. **Test Prioritization**
   - Run smoke tests first for quick failure detection
   - Group related tests for efficient resource usage
   - Prioritize based on historical failure rates

2. **Resource Management**
   - Limit parallel execution based on available resources
   - Implement proper cleanup between tests
   - Monitor resource usage to prevent exhaustion

3. **Failure Handling**
   - Collect comprehensive logs for debugging
   - Implement intelligent retry logic
   - Preserve failed test environments for investigation

4. **Reporting**
   - Generate reports at multiple detail levels
   - Include actionable recommendations
   - Track trends over time

## Future Enhancements

1. **Machine Learning Integration**
   - Predict test failures based on code changes
   - Optimize test ordering using historical data
   - Automatic root cause analysis

2. **Distributed Testing**
   - Support for multi-node test execution
   - Cloud resource provisioning
   - Geographic distribution for latency testing

3. **Advanced Analytics**
   - Performance regression detection
   - Resource usage optimization
   - Test coverage analysis