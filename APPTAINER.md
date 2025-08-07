# AlphaFold Apptainer/Singularity Guide

This guide provides comprehensive instructions for building and running AlphaFold using Apptainer (formerly Singularity) containers, with special attention to HPC environments and GPU compatibility.

## Table of Contents
- [Overview](#overview)
- [Available Definitions](#available-definitions)
- [Building Containers](#building-containers)
- [Running AlphaFold](#running-alphafold)
- [GPU Compatibility](#gpu-compatibility)
- [Troubleshooting](#troubleshooting)
- [Performance Tips](#performance-tips)

## Overview

Apptainer containers provide a portable, reproducible way to run AlphaFold on HPC systems. Our definitions have been extensively tested on ALCF systems with various GPU architectures.

### Key Features
- No root privileges required (with `--fakeroot`)
- Full GPU support (V100, A100, H100)
- Optimized for HPC environments
- Includes all dependencies

## Available Definitions

### 1. Ubuntu 20.04 (Most Stable)
**File**: `docker/alphafold_ubuntu20.def`
- **Best for**: Production use, maximum stability
- **Base**: `nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04`
- **Tested on**: H100, A100, V100 GPUs
- **Build time**: ~6-7 minutes

### 2. Ubuntu 22.04 (Modern Libraries)
**File**: `docker/alphafold_ubuntu22.def`
- **Best for**: Systems requiring newer libraries
- **Base**: `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04`
- **Special**: Includes CUDNN fixes for initialization issues
- **Build time**: ~7-8 minutes

## Building Containers

### Prerequisites
- Apptainer 1.1+ (or Singularity 3.8+)
- ~10GB free disk space
- Internet connection for downloading packages

### Build Commands

```bash
# Ubuntu 20.04 (recommended)
cd docker
apptainer build --fakeroot alphafold_ubuntu20.sif alphafold_ubuntu20.def

# Ubuntu 22.04 (with CUDNN fixes)
apptainer build --fakeroot alphafold_ubuntu22.sif alphafold_ubuntu22.def
```

### Build Options
- `--fakeroot`: Build without root privileges (recommended)
- `--sandbox`: Create writable directory instead of SIF (for development)
- `--nv`: Not needed during build, only at runtime

## Running AlphaFold

### Basic Usage

```bash
apptainer run --nv alphafold_ubuntu20.sif \
  --fasta_paths=target.fasta \
  --max_template_date=2022-01-01 \
  --db_preset=full_dbs \
  --model_preset=monomer \
  --data_dir=/path/to/alphafold/databases \
  --output_dir=/path/to/output
```

### Important Flags
- `--nv`: **Required** for GPU support
- `--bind`: Mount additional directories if needed
- `--pwd`: Set working directory inside container

### H100 GPU Special Configuration

Due to OpenMM compatibility issues with H100 GPUs (compute capability 9.0), use CPU relaxation:

```bash
apptainer run --nv alphafold_ubuntu20.sif \
  --fasta_paths=target.fasta \
  --max_template_date=2022-01-01 \
  --use_gpu_relax=false \  # Critical for H100
  --data_dir=/path/to/databases \
  --output_dir=/path/to/output
```

## GPU Compatibility

### Tested Configurations

| GPU Model | Architecture | GPU Relaxation | CPU Relaxation | Notes |
|-----------|-------------|----------------|----------------|--------|
| V100 | sm_70 | ✅ Works | ✅ Works | Full support |
| A100 | sm_80 | ✅ Works | ✅ Works | Full support |
| H100 | sm_90 | ❌ PTX Error | ✅ Works | Use CPU relaxation |

### Known Issues

1. **H100 PTX Error**: 
   - Error: `CUDA_ERROR_UNSUPPORTED_PTX_VERSION (222)`
   - Cause: conda-forge OpenMM lacks pre-compiled PTX for sm_90
   - Solution: Use `--use_gpu_relax=false`

2. **CUDNN Initialization (Ubuntu 22.04)**:
   - Error: `CUDNN_STATUS_NOT_INITIALIZED`
   - Solution: Use our Ubuntu 22.04 definition with fixes

## Troubleshooting

### Common Issues and Solutions

#### 1. Build Failures

**Held packages error**:
```
E: Held packages were changed and -y was used without --allow-change-held-packages
```
Solution: Our definitions include `--allow-change-held-packages`

**Temp directory permissions**:
```
rm: cannot remove '/tmp/...': Operation not permitted
```
Solution: Our definitions use `/var/tmp/alphafold-build`

#### 2. Runtime Issues

**No GPU detected**:
- Ensure `--nv` flag is used
- Check driver: `nvidia-smi`
- Verify CUDA compatibility

**Import errors**:
```
ModuleNotFoundError: No module named 'alphafold'
```
Solution: Check that files were copied correctly during build

#### 3. Performance Issues

**Slow MSA generation**:
- Use `--use_precomputed_msas` if available
- Ensure databases are on fast storage (NVMe preferred)
- Consider `--db_preset=reduced_dbs` for testing

### Debug Commands

```bash
# Test container dependencies
apptainer exec --nv alphafold.sif python -c "
import jax
print(f'JAX version: {jax.__version__}')
print(f'Devices: {jax.devices()}')
"

# Check GPU visibility
apptainer exec --nv alphafold.sif nvidia-smi

# Test AlphaFold import
apptainer exec --nv alphafold.sif python -c "import alphafold"
```

## Performance Tips

### 1. Database Optimization
- Place databases on fast storage (NVMe > SSD > HDD)
- Use `--db_preset=reduced_dbs` for development
- Consider database caching if running multiple predictions

### 2. GPU Utilization
- Monitor with `nvidia-smi` during runs
- H100 users: CPU relaxation has minimal impact (<5% total runtime)
- Use newest GPU drivers for best performance

### 3. Memory Management
```bash
# Set memory growth for TensorFlow
export TF_FORCE_GPU_ALLOW_GROWTH=true

# Limit JAX memory usage
export XLA_PYTHON_CLIENT_MEM_FRACTION=0.90
```

### 4. Parallel Runs
- Each AlphaFold process uses 1 GPU
- Safe to run multiple instances on multi-GPU nodes
- Ensure sufficient CPU memory (40GB+ per run)

## Advanced Usage

### Using Precomputed MSAs

```bash
apptainer run --nv alphafold.sif \
  --fasta_paths=target.fasta \
  --use_precomputed_msas=/path/to/msas \
  --max_template_date=2022-01-01 \
  --data_dir=/databases \
  --output_dir=/output
```

### Custom Bind Mounts

```bash
apptainer run --nv \
  --bind /scratch:/scratch \
  --bind /projects:/projects \
  alphafold.sif [arguments]
```

### Environment Variables

```bash
# Set inside container
export CUDA_VISIBLE_DEVICES=0  # Use specific GPU
export TF_CPP_MIN_LOG_LEVEL=2  # Reduce TF verbosity
export JAX_PLATFORMS=gpu       # Force GPU usage
```

## Testing

### Quick Validation Test

```bash
# Create test sequence
echo ">test
MKILLITIGTVLAVFTVFGIFNSVSAQKDNFGLTGGDVDQGFGQIRSDQTRDLVRKPKAAAKLL" > test.fasta

# Run with reduced databases
apptainer run --nv alphafold.sif \
  --fasta_paths=test.fasta \
  --max_template_date=2022-01-01 \
  --db_preset=reduced_dbs \
  --model_preset=monomer \
  --use_gpu_relax=false \
  --data_dir=/databases \
  --output_dir=test_output
```

Expected runtime: ~30-45 minutes with reduced databases

## Additional Resources

- [AlphaFold Documentation](https://github.com/deepmind/alphafold)
- [Apptainer Documentation](https://apptainer.org/docs/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/)
- Work reports in `reports/` directory for detailed development history

## Contributing

When contributing new definition files:
1. Test on multiple GPU architectures
2. Document any special requirements
3. Include troubleshooting for known issues
4. Update this guide with findings

## Version History

- **2025-08-07**: Added Ubuntu 22.04 with CUDNN fixes
- **2025-08-06**: Comprehensive H100 testing completed
- **2025-08-05**: Initial Ubuntu 20.04 definition created