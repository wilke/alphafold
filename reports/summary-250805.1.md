# AlphaFold Apptainer Container Build Summary Report

## Overview
Analysis of multiple AlphaFold container definitions in `/scratch` reveals the evolution of solutions to build a working Apptainer container from Docker. The successful build (`alphafold_final.def`) demonstrates critical fixes for CUDA/JAX GPU compatibility issues.

## Successful Build Evidence
- **Working container**: `/scratch/alphafold.sif`
- **Successful run**: `/scratch/alphafold_test_20250701_140302/` contains complete AlphaFold output with 5 models, MSAs, and relaxed structures

## Key Technical Challenges & Solutions

### 1. **GLIBC Compatibility**
- **Problem**: Host system GLIBC 2.35 incompatible with Ubuntu 20.04 containers
- **Solution**: Upgraded to `ubuntu22.04` base image in `alphafold_final.def`

### 2. **CUDA/CUDNN Library Issues**
- **Problem**: JAX unable to initialize CUDNN, causing GPU operations to hang
- **Solution**: Manual creation of all CUDNN symlinks:
  ```bash
  ln -sf libcudnn.so.8.9.6 libcudnn.so.8
  ln -sf libcudnn_adv_infer.so.8.9.6 libcudnn_adv_infer.so.8
  # ... (6 more symlinks)
  ```

### 3. **Conda Terms of Service**
- **Problem**: Conda 24.11.1 requires ToS acceptance for main/r channels
- **Current Issue**: Your optimized build still faces this problem
- **Solution in final.def**: Uses NVIDIA channel for CUDA packages, avoiding ToS complexity

### 4. **Database Path Handling**
- **Problem**: `--db_preset` flag not working properly in containers
- **Solution**: Enhanced wrapper script that auto-detects database paths from `--data_dir`

## Critical Success Factors

### From `alphafold_final.def`:
1. **Ubuntu 22.04 base** - GLIBC compatibility
2. **Comprehensive CUDNN symlinks** - Essential for JAX
3. **Enhanced wrapper script** with full environment setup
4. **Error-tolerant ldconfig**: `ldconfig 2>/dev/null || true`
5. **JAX 0.4.26** with explicit CUDA 12.2 support

### Environment Variables Required:
```bash
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/opt/conda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
export CUDA_MODULE_LOADING=EAGER
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export TF_FORCE_GPU_ALLOW_GROWTH=true
```

## Recommendations

1. **Use `alphafold_final.def` as template** - It's proven to work
2. **Avoid conda ToS complexity** - Use NVIDIA channel or accept ToS properly
3. **Include CUDNN symlinks** - Critical for GPU functionality
4. **Use Ubuntu 22.04** - Matches host GLIBC
5. **Implement comprehensive wrapper** - Handles environment and database paths

## Current Build Status
Your optimized build (`alphafold_apptainer_optimized.def`) incorporates some improvements but still has:
- Conda ToS issues (needs proper handling)
- Missing CUDNN symlinks
- Less comprehensive environment setup than `alphafold_final.def`

**Next Step**: Either use `alphafold_final.def` directly or incorporate its critical components into your optimized version.