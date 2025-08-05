# Docker Configurations Analysis

This directory contains three different Dockerfile configurations for building AlphaFold containers, each serving specific deployment scenarios.

## Dockerfile Overview

### 1. **Dockerfile** (Main/Default)
**Purpose**: The primary production Dockerfile with flexible CUDA support

**Key Features**:
- **CUDA Version**: Parameterized via ARG (default: 12.2.2)
- **JAX Version**: 0.4.26 (latest)
- **Base Image**: `nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04`
- **Entrypoint**: Uses ldconfig wrapper script for GPU visibility
- **Special Features**: 
  - Sets SETUID on `/sbin/ldconfig.real` for non-root users
  - Uses bash shell with pipefail for robust error handling
  - Dynamic CUDA command-line tools installation

**Use Case**: Production deployments requiring flexibility across different CUDA versions

### 2. **Dockerfile.alphafold**
**Purpose**: Stable, optimized build with fixed versions and performance tuning

**Key Features**:
- **CUDA Version**: Hardcoded to 12.2.2
- **JAX Version**: 0.4.23 (older, more stable)
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04`
- **Additional Optimizations**:
  - Docker labels for metadata tracking
  - CUDA performance environment variables:
    - `CUDA_FORCE_PTX_JIT=1`
    - `XLA_FLAGS="--xla_gpu_force_compilation_parallelism=1"`
  - More explicit CUDA package installation via conda
  - Sets `PYTHONPATH` explicitly

**Use Case**: Production environments requiring stable, well-tested configurations with CUDA optimizations

### 3. **Dockerfile.ubuntu**
**Purpose**: Simplified build without ldconfig wrapper

**Key Features**:
- **CUDA Version**: Parameterized via ARG
- **JAX Version**: 0.4.26 (latest)
- **Base Image**: Same as main Dockerfile
- **Entrypoint**: Direct Python execution without ldconfig wrapper
- **Simplified**: 
  - No SETUID on ldconfig.real
  - No shell script wrapper
  - Direct ENTRYPOINT to Python

**Use Case**: Environments where GPU visibility issues don't occur or simplified container runtime is preferred

## Comparison Table

| Feature | Dockerfile | Dockerfile.alphafold | Dockerfile.ubuntu |
|---------|------------|---------------------|-------------------|
| **CUDA Version** | Parameterized (ARG) | Fixed 12.2.2 | Parameterized (ARG) |
| **JAX Version** | 0.4.26 | 0.4.23 | 0.4.26 |
| **ldconfig wrapper** | Yes | Yes | No |
| **SETUID ldconfig** | Yes | Yes | No |
| **CUDA env vars** | No | Yes (optimizations) | No |
| **Docker labels** | No | Yes | No |
| **Shell** | Bash with pipefail | Standard | Bash with pipefail |
| **Python path** | Not set | Explicitly set | Not set |

## Common Features

All three Dockerfiles share:
- Ubuntu 20.04 base (via CUDA image)
- HHsuite v3.3.0 compiled from source
- Miniconda installation for package management
- OpenMM 8.0.0 and pdbfixer for structure relaxation
- stereo_chemical_props.txt download
- Python 3.11 environment
- CUDA 12.2.2 with cuDNN 8

## Recommendations

1. **For most users**: Use the main `Dockerfile` for flexibility
2. **For production with known hardware**: Use `Dockerfile.alphafold` for optimized performance
3. **For simplified deployments**: Use `Dockerfile.ubuntu` if GPU detection works without ldconfig

## Building

```bash
# Main Dockerfile (with custom CUDA version)
docker build -f Dockerfile --build-arg CUDA=12.2.2 -t alphafold .

# Optimized AlphaFold build
docker build -f Dockerfile.alphafold -t alphafold:optimized .

# Simplified Ubuntu build
docker build -f Dockerfile.ubuntu -t alphafold:simple .
```

## Notes

- The ldconfig wrapper addresses GPU visibility issues on some systems (see [NVIDIA Docker issue #1399](https://github.com/NVIDIA/nvidia-docker/issues/1399))
- JAX version differences (0.4.23 vs 0.4.26) may affect performance and compatibility
- All containers require NVIDIA Docker runtime (`--gpus all` flag when running)