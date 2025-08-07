# Test Orchestration Agent

## Overview

The test-orchestration-agent automates complex testing workflows for scientific computing containers, particularly focused on AlphaFold Apptainer/Singularity definitions. It saves 3-4 hours per test cycle by intelligently managing test execution, monitoring, and analysis.

## Key Benefits

- **Time Savings**: 3-4 hours per test cycle (75% reduction)
- **Intelligent Orchestration**: Optimal test ordering and parallel execution
- **Automated Analysis**: Pattern recognition and failure categorization
- **Comprehensive Reporting**: Multiple format outputs with actionable insights

## Quick Start

### Using with Claude Code

To invoke the test orchestration agent, use Claude Code's Task tool:

```
Task tool parameters:
- subagent_type: "general-purpose"
- description: "Orchestrate AlphaFold tests"
- prompt: "Acting as a test-orchestration-agent, [your specific request]"
```

### Example Usage

```
Description: Run AlphaFold test suite
Prompt: Acting as a test-orchestration-agent, execute the AlphaFold container test matrix defined in agents/templates/test_matrix_alphafold.yaml. Monitor progress, analyze failures, and generate comprehensive report.
```

## Core Features

### 1. Test Matrix Management
- Parameterized test configurations
- Dependency-aware execution
- Resource allocation optimization
- Intelligent failure prediction

### 2. Execution Orchestration
- Parallel build and test execution
- Real-time progress monitoring
- Adaptive resource management
- Automatic retry logic

### 3. Failure Analysis
- Pattern recognition across failures
- Root cause categorization
- Historical correlation
- Solution recommendations

### 4. Comprehensive Reporting
- Multiple output formats (Markdown, JSON, JUnit)
- Performance metrics and trends
- Actionable recommendations
- CI/CD integration support

## Test Matrix Configuration

The agent uses YAML configuration files to define test parameters:

```yaml
test_suite:
  name: "AlphaFold Container Tests"
  parameters:
    definition_files:
      - alphafold_ubuntu20.def
      - alphafold_ubuntu22.def
    configurations:
      - use_gpu_relax: true
      - use_gpu_relax: false
```

See `templates/test_matrix_alphafold.yaml` for complete example.

## Error Pattern Recognition

The agent maintains a database of known error patterns:

| Error Type | Pattern | Solution |
|------------|---------|----------|
| PTX Version | `CUDA_ERROR_UNSUPPORTED_PTX_VERSION` | Use CPU relaxation or source-build OpenMM |
| CUDNN Init | `CUDNN_STATUS_NOT_INITIALIZED` | Install dev packages, fix symlinks |
| Held Packages | `Held packages were changed` | Add --allow-change-held-packages |

## Monitoring Dashboard

The agent provides real-time monitoring during execution:

```
Test Progress: [████████████░░░░] 75% (6/8)
Current: ubuntu22_source_gpu (Running 15m)
GPU: 80% | Memory: 45GB/80GB
Recent: ✓ ubuntu20_cpu ✗ ubuntu22_gpu (PTX)
```

## Output Examples

### Markdown Report
- Executive summary with pass/fail statistics
- Detailed test results table
- Failure analysis with patterns
- Performance metrics
- Recommendations for production

### JSON Summary
```json
{
  "total_tests": 8,
  "passed": 1,
  "failed": 7,
  "patterns": {
    "ptx_errors": 2,
    "cudnn_errors": 3
  }
}
```

## Integration with Existing Tools

The agent integrates with:
- `run_alphafold_test.sh` - Single test execution
- `run_all_alphafold_tests.sh` - Batch orchestration
- Build systems (Apptainer, Docker)
- CI/CD pipelines

## Best Practices

1. **Define Clear Success Criteria**
   - Set expected pass rates
   - Define performance thresholds
   - Specify critical vs. optional tests

2. **Optimize Resource Usage**
   - Limit parallel execution based on resources
   - Implement proper cleanup
   - Use build caching effectively

3. **Enable Comprehensive Logging**
   - Capture all build and test outputs
   - Preserve artifacts for debugging
   - Track metrics for trend analysis

## Advanced Usage

### Custom Test Ordering
```
Prompt: Acting as a test-orchestration-agent, optimize test execution order based on:
1. Historical failure rates (fail-fast)
2. Resource requirements (efficient packing)
3. Dependencies (respect prerequisites)
```

### Regression Testing
```
Prompt: Acting as a test-orchestration-agent, compare current test results with baseline from [date]. Identify regressions, performance changes, and new failures.
```

### Multi-Architecture Testing
```
Prompt: Acting as a test-orchestration-agent, test AlphaFold across V100, A100, and H100 GPUs. Create architecture-specific compatibility matrix.
```

## Troubleshooting

### Common Issues

1. **Resource Exhaustion**
   - Reduce parallel execution limits
   - Implement cleanup between tests
   - Monitor resource usage

2. **Test Timeouts**
   - Adjust timeout values in configuration
   - Check for hanging processes
   - Verify network connectivity

3. **Inconsistent Results**
   - Ensure clean environment between tests
   - Check for race conditions
   - Verify test data integrity

## Future Enhancements

- Machine learning for failure prediction
- Distributed test execution
- Advanced performance analytics
- Automatic fix generation

## Related Agents

- `container-build-agent` - For creating optimized definitions
- `gpu-compatibility-agent` - For hardware-specific issues
- `performance-analysis-agent` - For detailed metrics