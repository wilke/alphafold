# Container Build Agent for Claude Code

## Agent Description

**container-build-agent**: Use this agent to automatically generate, optimize, and troubleshoot Apptainer/Singularity container definitions for scientific computing applications. The agent handles dependency resolution, build optimization, and failure analysis.

## Agent Capabilities

### 1. Definition File Generation
- Generate optimized Apptainer definition files from templates
- Support multiple base OS versions (Ubuntu 20.04, 22.04, etc.)
- Automatic dependency version selection based on compatibility matrix
- GPU architecture-specific optimizations

### 2. Dependency Conflict Resolution
- Analyze package dependencies and version constraints
- Automatically resolve conflicts between conda, pip, and apt packages
- Suggest alternative packages when conflicts cannot be resolved
- Maintain compatibility matrix for known working configurations

### 3. Build Cache Management
- Identify cacheable build stages
- Optimize build order for maximum cache utilization
- Track build artifacts and reuse across definitions
- Estimate build time based on cache availability

### 4. Build Failure Analysis
- Parse build logs to identify root causes
- Match error patterns against known issues database
- Provide actionable fix recommendations
- Generate automated patches for common issues

## Usage Examples

### Example 1: Generate AlphaFold Container with H100 Support
```
Task: Generate an optimized AlphaFold container definition with H100 GPU support

The agent will:
1. Analyze hardware requirements (H100 = sm_90 architecture)
2. Detect that conda-forge OpenMM lacks H100 support
3. Automatically generate definition with OpenMM source build
4. Include all necessary CUDA flags and dependencies
```

### Example 2: Fix Build Failures
```
Task: Analyze and fix AlphaFold container build failure

The agent will:
1. Parse error logs to identify failure type
2. Match against known patterns (e.g., held packages, missing dependencies)
3. Generate corrected definition file
4. Provide explanation of changes made
```

### Example 3: Optimize Build Performance
```
Task: Optimize AlphaFold container build for faster iteration

The agent will:
1. Analyze current definition for optimization opportunities
2. Reorder stages for better cache utilization
3. Parallelize compilation where possible
4. Estimate time savings from optimizations
```

## Template System

### Base Templates

```yaml
# templates/base_ubuntu22.yaml
base:
  image: nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04
  
environment:
  CUDA_HOME: /usr/local/cuda
  PYTHONNOUSERSITE: "true"
  
packages:
  system:
    - build-essential
    - git
    - wget
    - cmake
  python:
    version: "3.11"
    packages:
      - numpy
      - scipy
      - jax[cuda12]
```

### Application Templates

```yaml
# templates/alphafold.yaml
extends: base_ubuntu22

application:
  name: alphafold
  version: "2.3.2"
  
dependencies:
  conda:
    - conda-forge::openmm=8.0.0  # Override for H100: build from source
    - bioconda::hmmer=3.3.2
    - bioconda::kalign2=2.04
  
  pip:
    - alphafold[standard]
    - dm-haiku==0.0.9
    - ml-collections==0.1.1
    
gpu_support:
  architectures:
    - sm_80  # A100
    - sm_90  # H100
  
  special_cases:
    h100:
      openmm:
        build_from_source: true
        cmake_flags: "-DOPENMM_CUDA_COMPILER_FLAGS='-gencode arch=compute_90,code=sm_90'"
```

## Error Pattern Database

```yaml
# patterns/build_errors.yaml
errors:
  - pattern: "E: Held packages were changed"
    solution: "Add --allow-change-held-packages to apt-get"
    
  - pattern: "CUDA_ERROR_UNSUPPORTED_PTX_VERSION"
    solution: "Build OpenMM from source with target GPU architecture"
    
  - pattern: "No module named 'openmm'"
    solution: "Ensure OpenMM is installed in the correct conda environment"
    
  - pattern: "/tmp/.*: Operation not permitted"
    solution: "Use custom TMPDIR instead of cleaning /tmp"
```

## Implementation Strategy

The agent should:

1. **Parse Requirements**
   - Extract hardware targets, OS version, package requirements
   - Identify special cases (e.g., H100 GPU needs)

2. **Generate Definition**
   - Load appropriate base template
   - Apply application-specific overlays
   - Handle special cases and optimizations

3. **Validate**
   - Check dependency compatibility
   - Verify GPU architecture support
   - Estimate resource requirements

4. **Optimize**
   - Order stages for cache efficiency
   - Minimize layer count
   - Parallelize where possible

5. **Provide Guidance**
   - Build instructions
   - Troubleshooting tips
   - Performance expectations