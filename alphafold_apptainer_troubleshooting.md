# AlphaFold Apptainer Container Troubleshooting Guide

This document chronicles all errors encountered and solutions attempted while building an Apptainer/Singularity container for AlphaFold with CUDA PTX compatibility fixes.

## Overview

**Goal**: Build a working Apptainer container (`alphafold_debug.sif`) from the AlphaFold docker definition file that resolves CUDA PTX compatibility issues and enables GPU acceleration for JAX computations.

**Core Issue**: JAX hangs when attempting GPU computations due to CUDNN initialization failures, despite detecting GPUs correctly.

## Errors and Solutions

### 1. GLIBC Version Mismatch

**Error**:
```
/.singularity.d/libs/faked: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.33' not found
/.singularity.d/libs/faked: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found
```

**Cause**: The host system has a newer GLIBC version than the container's Ubuntu 20.04 base image.

**Solutions Attempted**:
1. ❌ Initial build with Ubuntu 20.04 base - Failed due to GLIBC incompatibility
2. ✅ **Switch to Ubuntu 22.04 base** - Successfully resolved GLIBC issues
   ```
   From: nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04
   # Changed to:
   From: nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04
   ```

### 2. Missing Test Scripts Directory

**Error**:
```
FATAL: While performing build: conveyor failed to get: copying [/home/user/test_scripts] to rootfs: 
stat /home/user/test_scripts: no such file or directory
```

**Cause**: Relative path in the definition file was incorrect.

**Solution**:
✅ **Use absolute path to CEPI test scripts**:
```bash
# From:
test_scripts /app/test_scripts

# To:
/nfs/ml_lab/projects/ml_lab/cepi/alphafold/CEPI/test_scripts /app/test_scripts
```

### 3. CUDNN Initialization Failure

**Error**:
```
Could not create cudnn handle: CUDNN_STATUS_NOT_INITIALIZED
Could not create cudnn handle: CUDNN_STATUS_INTERNAL_ERROR
```

**Cause**: JAX cannot properly initialize CUDNN libraries, despite CUDA being available.

**Solutions Attempted**:

1. ❌ **Environment Variables** - Set various CUDA/JAX environment variables:
   ```bash
   export CUDA_MODULE_LOADING=EAGER
   export XLA_PYTHON_CLIENT_PREALLOCATE=false
   export XLA_PYTHON_CLIENT_ALLOCATOR=platform
   export TF_FORCE_GPU_ALLOW_GROWTH=true
   export TF_GPU_THREAD_MODE=gpu_private
   export XLA_FLAGS="--xla_gpu_force_compilation_parallelism=1 --xla_gpu_enable_async_collectives=false"
   ```

2. ❌ **ldconfig Configuration** - Attempted to update library cache:
   ```bash
   # Added SETUID bit to allow non-root users to run ldconfig
   chmod u+s /sbin/ldconfig.real
   
   # Created wrapper scripts that run ldconfig before Python
   echo '#!/bin/bash
   ldconfig 2>/dev/null || true
   export LD_LIBRARY_PATH="/opt/conda/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
   exec python "$@"' > /app/python_wrapper.sh
   ```

3. ❌ **CUDNN Symlinks** - Created missing symlinks that JAX expects:
   ```bash
   cd /usr/lib/x86_64-linux-gnu/
   ln -sf libcudnn.so.8.9.6 libcudnn.so.8
   ln -sf libcudnn.so.8 libcudnn.so
   ln -sf libcudnn_adv_infer.so.8.9.6 libcudnn_adv_infer.so.8
   ln -sf libcudnn_adv_train.so.8.9.6 libcudnn_adv_train.so.8
   ln -sf libcudnn_cnn_infer.so.8.9.6 libcudnn_cnn_infer.so.8
   ln -sf libcudnn_cnn_train.so.8.9.6 libcudnn_cnn_train.so.8
   ln -sf libcudnn_ops_infer.so.8.9.6 libcudnn_ops_infer.so.8
   ln -sf libcudnn_ops_train.so.8.9.6 libcudnn_ops_train.so.8
   ```

4. ❌ **Different JAX/CUDNN Versions** - Tried multiple combinations:
   - JAX 0.4.26 with jaxlib 0.4.26+cuda12.cudnn89 (from requirements.txt)
   - JAX 0.4.23 with CUDA 12.2 support
   - CUDNN via conda-forge for better compatibility

### 4. Read-only Filesystem for ldconfig

**Error**:
```
/sbin/ldconfig.real: Can't create temporary cache file /etc/ld.so.cache~: Read-only file system
```

**Cause**: Container filesystem is read-only at runtime for ldconfig operations.

**Solutions Attempted**:
1. ✅ **Wrapper scripts with error suppression**:
   ```bash
   ldconfig 2>/dev/null || true
   ```
2. ✅ **Run ldconfig during build phase** to pre-populate cache

### 5. JAX GPU Computation Hanging

**Error**: No explicit error message - JAX detects GPUs but hangs indefinitely when attempting actual GPU computations.

**Diagnostic Output**:
```
JAX devices: [cuda(id=0), cuda(id=1), cuda(id=2), cuda(id=3), cuda(id=4)]
# Then hangs on any GPU operation like:
x = jax.numpy.array([1.0])
```

**Solutions Attempted**:
1. ❌ Various XLA flags to disable optimizations
2. ❌ Different memory allocation strategies
3. ❌ Installing CUDNN via conda-forge instead of relying on base image
4. ❌ Different JAX versions known to work with CUDA 12.2

## Container Definition Files Created

### 1. `/scratch/alphafold_ubuntu22.def`
- First successful build after switching to Ubuntu 22.04
- Resolved GLIBC issues but had CUDNN problems

### 2. `/scratch/alphafold_ldconfig.def`
- Added ldconfig wrapper scripts
- Attempted to fix library visibility issues

### 3. `/scratch/alphafold_final.def`
- Added comprehensive CUDNN symlinks
- Most complete attempt with all known fixes

### 4. `/scratch/alphafold_jax_fix.def`
- Used JAX 0.4.23 with specific CUDA 12.2 support
- Installed CUDNN via conda-forge
- Added extensive environment variables and XLA flags

## Test Scripts Used

### 1. `/scratch/test_cuda_simple.py`
- Basic CUDA/JAX availability test
- Minimal JAX operations to isolate hanging issue

### 2. `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/CEPI/test_scripts/test_jax_cuda.py`
- Comprehensive JAX-CUDA PTX validation
- Tests various operations that trigger PTX compilation
- Provides detailed error reporting for PTX issues

## Final Resolution - December 2024

✅ **SOLVED**: Successfully created working AlphaFold Apptainer container

### Root Causes Identified:
1. **NumPy Version Incompatibility**: JAX 0.4.23-0.4.26 requires NumPy < 2.0, but pip was installing NumPy 2.x by default
2. **User Package Interference**: Apptainer was loading JAX from user's home directory instead of container packages
3. **GLIBC Version Mismatch**: Ubuntu 20.04 base was incompatible with host GLIBC 2.35
4. **Missing CUDA Development Tools**: ptxas compiler needed for GPU JIT compilation

### Working Solution:
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04`
- **NumPy**: Explicitly install 1.24.3 (from AlphaFold requirements.txt)
- **JAX**: 0.4.26 with jaxlib 0.4.26+cuda12.cudnn89
- **Isolation**: Use PYTHONNOUSERSITE=1 to prevent user package interference
- **CUDA Tools**: Bind mount host ptxas or include cuda-toolkit-12-2 in container

### Test Results:
```
✓ NumPy 1.24.3
✓ JAX 0.4.26
  Devices: [cuda(id=0)]
✓ TensorFlow 2.16.1
✓ AlphaFold module imported successfully
```

### Current Status (v1.1)

Container builds and runs successfully with proper GPU support. See `alphafold_apptainer_final_report.md` for complete details.

## Recommendations for Further Investigation

1. **Test with different CUDA versions**: Try CUDA 11.8 or 12.1 which have better JAX compatibility
2. **Use official JAX Docker images**: Start from JAX's official containers and add AlphaFold
3. **Driver compatibility**: Verify host NVIDIA driver version matches container CUDA version
4. **Strace analysis**: Run with strace to see exactly where the hang occurs
5. **Alternative approach**: Use Docker instead of Apptainer to isolate if it's a container runtime issue

## Build Commands Reference

```bash
# Build with fakeroot (always required)
apptainer build --fakeroot /scratch/alphafold_debug.sif /scratch/alphafold_jax_fix.def

# Test basic functionality
apptainer exec --nv /scratch/alphafold_debug.sif /app/python_wrapper.sh /scratch/test_cuda_simple.py

# Run comprehensive tests
apptainer exec --nv /scratch/alphafold_debug.sif /app/python_wrapper.sh /app/test_scripts/test_jax_cuda.py

# Interactive debugging
apptainer shell --nv /scratch/alphafold_debug.sif
```

## Key Learnings

1. **GLIBC compatibility** is critical - container base OS must match or exceed host GLIBC version
2. **CUDNN initialization** in containers requires careful library path management
3. **JAX is sensitive** to CUDA/CUDNN versions and configurations
4. **Wrapper scripts** can help manage environment setup but have limitations
5. **--fakeroot flag** is essential for Apptainer builds to avoid permission issues