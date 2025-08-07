#!/usr/bin/env python3
"""
Example of using container-build-agent pattern with Claude Code

This demonstrates how to invoke the container-build-agent to generate
optimized Apptainer definitions based on our learnings from the H100
GPU compatibility issues.
"""

# Example 1: Generate H100-optimized AlphaFold container
h100_request = """
Acting as a container-build-agent, generate an optimized Apptainer definition for AlphaFold with H100 GPU support.

Requirements:
- Target hardware: NVIDIA H100 GPU (sm_90)
- Base OS: Ubuntu 22.04
- Python: 3.11
- Must support GPU relaxation
- Optimize for build caching

Known issues to address:
1. conda-forge OpenMM 8.0.0 lacks pre-compiled PTX for sm_90
2. apt-get held packages error requires --allow-change-held-packages
3. /tmp cleanup causes permission errors in build

Use the patterns from:
- /nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/alphafold_ubuntu22_openmm_source.def
- Error patterns from build logs

Generate:
1. Complete optimized definition file
2. Build instructions with timing estimates
3. Validation checklist
4. Common error solutions
"""

# Example 2: Fix build failure
fix_build_request = """
Acting as a container-build-agent, analyze this AlphaFold build failure and provide a fix:

Error log:
```
E: Held packages were changed and -y was used without --allow-change-held-packages.
FATAL:   While performing build: while running engine: exit status 100
```

Current definition file: alphafold_ubuntu22.def
Target: Ubuntu 22.04 with CUDA 12.2

Provide:
1. Root cause analysis
2. Fixed definition file snippet
3. Explanation of changes
4. Prevention strategies
"""

# Example 3: Optimize for caching
optimize_cache_request = """
Acting as a container-build-agent, optimize this AlphaFold definition for better build caching:

Current build stages:
1. Install system packages (changes frequently)
2. Install CUDA/cuDNN (rarely changes)
3. Install conda (rarely changes)
4. Install Python packages (changes moderately)
5. Install AlphaFold (changes with updates)

Current build time: 25 minutes uncached
Goal: Reduce rebuild time when only AlphaFold changes

Provide:
1. Reordered build stages
2. Cache-friendly definition structure
3. Expected time savings
4. Cache management tips
"""

# Example 4: Multi-architecture support
multi_arch_request = """
Acting as a container-build-agent, create a definition that supports multiple GPU architectures:

Requirements:
- Support GPUs: V100 (sm_70), A100 (sm_80), H100 (sm_90)
- Single definition file
- Graceful fallback for unsupported architectures
- Optimize for size (avoid redundant compilations)

Provide:
1. Multi-architecture definition
2. Runtime detection logic
3. Performance implications
4. Testing strategy for each architecture
"""

# Example usage in Claude Code:
# When you want to use the container-build-agent, you would use the Task tool
# with "general-purpose" as the subagent_type and include the agent behavior
# in your prompt, similar to the examples above.

if __name__ == "__main__":
    print("Container Build Agent Usage Examples")
    print("=" * 50)
    print("\nExample prompts for different scenarios:")
    print("\n1. H100 Optimization Request:")
    print(h100_request)
    print("\n2. Build Failure Fix Request:")
    print(fix_build_request)
    print("\n3. Cache Optimization Request:")
    print(optimize_cache_request)
    print("\n4. Multi-Architecture Request:")
    print(multi_arch_request)