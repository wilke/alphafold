# Container Configurations Analysis

This directory contains Docker and Apptainer/Singularity configurations for building AlphaFold containers, each serving specific deployment scenarios.

## Apptainer/Singularity Definition

### **alphafold_ubuntu20.def**
**Purpose**: Production-ready Apptainer/Singularity definition for HPC environments

**Key Features**:
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04`
- **Ubuntu Version**: 20.04 LTS (proven stable in testing)
- **OpenMM**: 8.0.0 from conda-forge
- **GPU Support**: Works with V100, A100 (H100 requires CPU relaxation mode)
- **Build Optimizations**:
  - Custom temp directory to avoid /tmp conflicts
  - Auto-accepts conda plugin terms of service
  - Handles apt held packages gracefully
  - Cleaned up build artifacts for smaller image size

**Validated Configuration**:
- Tested successfully on H100 GPUs with `--use_gpu_relax=false`
- Full GPU relaxation works on older architectures (V100, A100)
- Build time: ~6-7 minutes
- Test time: ~32 minutes for single protein

**Use Case**: HPC environments, especially ALCF systems with Apptainer support

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

### Apptainer/Singularity
```bash
# Build the Apptainer image (requires fakeroot or sudo)
apptainer build --fakeroot alphafold_ubuntu20.sif alphafold_ubuntu20.def

# For H100 systems, use with CPU relaxation
python run_alphafold.py \
  --fasta_paths=target.fasta \
  --max_template_date=2022-01-01 \
  --use_gpu_relax=false \
  --data_dir=/path/to/databases \
  --output_dir=/path/to/output
```

### Docker
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
- For H100 GPUs: Use CPU relaxation mode (`--use_gpu_relax=false`) due to OpenMM PTX compatibility issues
- Apptainer definition tested on ALCF systems with comprehensive validation