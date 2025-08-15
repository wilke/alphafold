# Container Configurations Analysis

This directory contains Docker and Apptainer/Singularity configurations for building AlphaFold containers, each serving specific deployment scenarios.

## Apptainer/Singularity Definitions

### 1. **alphafold_unified_patric.def** ⭐ **PRODUCTION**
**Purpose**: Unified AlphaFold + Patric Runtime + BV-BRC Service Framework container

**Key Features**:
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04`
- **Ubuntu Version**: 22.04 LTS with CUDNN 8.9.7
- **Integration Components**:
  - AlphaFold v2.3.2 - GPU-accelerated protein structure prediction
  - Patric Runtime - 70GB bioinformatics toolchain
  - BV-BRC Service Framework - Computational biology service orchestration
- **Container Apps**:
  - Default: AlphaFold prediction
  - `bvbrc`: BV-BRC service mode
  - `patric-env`: Patric tools environment
  - `test`: Integration validation
- **Size**: ~24.7GB
- **Build Time**: ~45-60 minutes

**Validated Configuration**:
- Successfully integrates three major scientific frameworks
- GPU acceleration maintained with CUDA 12.2.2
- Multi-framework environment isolation working
- Comprehensive integration testing included

**Use Case**: Production HPC deployments requiring AlphaFold + Patric bioinformatics tools

**Usage Examples**:
```bash
# AlphaFold prediction
apptainer run --nv alphafold_unified_patric.sif --fasta_paths=protein.fasta [args]

# Patric tools
apptainer run --app patric-env alphafold_unified_patric.sif CoreSNP.py --help

# BV-BRC service
apptainer run --app bvbrc alphafold_unified_patric.sif job_id app_def.json params.json
```

### 2. **patric_addon.def** ⭐ **DEVELOPMENT**
**Purpose**: Lightweight addon for layered container builds (90% faster)

**Key Features**:
- **Base Container**: Uses existing `alphafold_ubuntu22_cudnn896.sif` as foundation
- **Addon Components**: Only Patric runtime + BV-BRC integration
- **Build Strategy**: Layered approach - reuses proven AlphaFold base
- **Build Time**: ~5-10 minutes (vs 60+ minutes for monolithic)
- **Efficiency**: 90% faster builds for development iterations

**Architecture Benefits**:
- ✅ Reuses proven AlphaFold base (8.2GB)
- ✅ Minimal risk (only addon can fail)
- ✅ Easy maintenance (update layers independently)
- ✅ Development-friendly (fast iteration cycles)

**Use Case**: Development workflows, frequent container updates, CI/CD pipelines

**Note**: Requires `alphafold_ubuntu22_cudnn896.sif` as base container

### 3. **alphafold_ubuntu22_cudnn896.def** ⭐ **BASE CONTAINER**
**Purpose**: Production-ready AlphaFold base for Ubuntu 22.04 (optimal for layered builds)

**Key Features**:
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04`
- **Ubuntu Version**: 22.04 LTS with CUDNN 8.9.6 (downgraded)
- **OpenMM**: 8.0.0 from conda-forge
- **GPU Support**: Works with V100, A100, H100 (with CPU relaxation)
- **Key Improvements**:
  - Manually installs CUDNN 8.9.6 to avoid 8.9.7 bug
  - Packages held to prevent auto-upgrade
  - Full JAX/GPU compatibility verified
  - Same performance as Ubuntu 20.04 version

**Validated Configuration**:
- Successfully resolves CUDNN_STATUS_NOT_INITIALIZED errors
- Full GPU detection (8 devices on H100 systems)
- Build time: ~8 minutes
- JAX operations confirmed working

**Use Case**: Base layer for layered builds, modern HPC environments requiring Ubuntu 22.04

### 4. **alphafold_ubuntu20.def**
**Purpose**: Legacy AlphaFold container for Ubuntu 20.04 compatibility

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

**Use Case**: Legacy HPC environments, compatibility with older Ubuntu 20.04 systems

### 5. **alphafold_ubuntu22.def** ⚠️ **REFERENCE ONLY**
**Purpose**: Ubuntu 22.04 reference definition (has CUDNN issues)

**Key Features**:
- **Base Image**: `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04`
- **Ubuntu Version**: 22.04 LTS with CUDNN 8.9.7
- **Known Issue**: CUDNN_STATUS_NOT_INITIALIZED error with JAX
- **Status**: Non-functional due to CUDNN 8.9.7 bug

**Use Case**: Reference only - use alphafold_ubuntu22_cudnn896.def instead

## Docker Configuration

### **Dockerfile** (Main/Default)
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

**Use Case**: Docker-based deployments requiring flexibility across different CUDA versions

## Container Strategy Comparison

| Approach | Build Time | Use Case | Efficiency | Risk Level |
|----------|------------|----------|------------|------------|
| **Unified (Patric)** | ~60 min | Production deployment | Medium | Low |
| **Layered (Addon)** | ~10 min | Development iteration | High (90% faster) | Low |
| **Base Only** | ~8 min | Foundation for layering | High | Low |
| **Legacy (Ubuntu20)** | ~7 min | Compatibility needs | Medium | Low |

## Architecture Overview

### Unified Container (`alphafold_unified_patric.def`)
```
┌─────────────────────────────────────────┐
│           Unified Container             │
├─────────────────────────────────────────┤
│ AlphaFold v2.3.2 + Patric + BV-BRC     │
│ ┌─────────────┬─────────────┬─────────┐ │
│ │ AlphaFold   │ Patric      │ BV-BRC  │ │
│ │ - JAX 0.4.26│ - 70GB      │ - Perl  │ │
│ │ - TensorFlow│   Runtime   │   Service│ │
│ │ - OpenMM    │ - CoreSNP   │ - Jobs  │ │
│ └─────────────┴─────────────┴─────────┘ │
├─────────────────────────────────────────┤
│     Ubuntu 22.04 + CUDA 12.2.2         │
└─────────────────────────────────────────┘
```

### Layered Container (`patric_addon.def`)
```
┌─────────────────────────────────────────┐
│            Addon Layer                  │
├─────────────────────────────────────────┤
│ Patric Runtime + BV-BRC (~2GB)          │
│ ┌─────────────┬─────────────────────────┐ │
│ │ Patric      │ BV-BRC Integration      │ │
│ │ - Tools     │ - Service Framework     │ │
│ │ - Scripts   │ - Job Management        │ │
│ └─────────────┴─────────────────────────┘ │
├─────────────────────────────────────────┤
│        Base Container (8.2GB)           │
│ ┌─────────────────────────────────────┐ │
│ │ AlphaFold v2.3.2 Complete          │ │
│ │ - JAX, TensorFlow, OpenMM           │ │
│ │ - All scientific dependencies       │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│     Ubuntu 22.04 + CUDA 12.2.2         │
└─────────────────────────────────────────┘
```

## Container Applications

### Unified Container Apps
| App Name | Purpose | Usage |
|----------|---------|-------|
| **Default** | AlphaFold prediction | `apptainer run --nv container.sif [args]` |
| **bvbrc** | BV-BRC service mode | `apptainer run --app bvbrc container.sif [args]` |
| **patric-env** | Patric tools environment | `apptainer run --app patric-env container.sif [tool]` |
| **test** | Integration validation | `apptainer run --app test container.sif` |

## Common Features

All AlphaFold containers share:
- Ubuntu base (20.04 or 22.04)
- HHsuite v3.3.0 compiled from source
- Miniconda installation for package management
- OpenMM 8.0.0 and pdbfixer for structure relaxation
- stereo_chemical_props.txt download
- Python 3.11 environment
- CUDA 12.2.2 with cuDNN 8

## Recommendations

### For Production Deployments
1. **Single Framework Need**: Use `alphafold_ubuntu22_cudnn896.def` for pure AlphaFold
2. **Multi-Framework Need**: Use `alphafold_unified_patric.def` for AlphaFold + Patric tools
3. **Legacy Systems**: Use `alphafold_ubuntu20.def` for Ubuntu 20.04 compatibility

### For Development Workflows
1. **Frequent Updates**: Use layered approach (`patric_addon.def` + base)
2. **CI/CD Pipelines**: Leverage 90% faster build times with layered containers
3. **Testing**: Use unified container's built-in test applications

### For Container Strategy
- **Build Once, Deploy Many**: Use unified containers
- **Iterate Often**: Use layered approach for development
- **Mix Approaches**: Build unified for production, layered for development

## Building

### Apptainer/Singularity
```bash
# Production unified container (AlphaFold + Patric + BV-BRC)
apptainer build --fakeroot alphafold_unified_patric.sif alphafold_unified_patric.def

# Base container for layered builds
apptainer build --fakeroot alphafold_ubuntu22_cudnn896.sif alphafold_ubuntu22_cudnn896.def

# Layered addon (requires base container)
apptainer build --fakeroot alphafold_patric_layered.sif patric_addon.def

# Legacy Ubuntu 20.04
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
```

## Production Deployment Locations

- **Production Unified Container**: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/alphafold_unified_patric.sif`
- **Base Container**: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/alphafold_ubuntu22_cudnn896.sif`

## Notes

- The ldconfig wrapper addresses GPU visibility issues on some systems (see [NVIDIA Docker issue #1399](https://github.com/NVIDIA/nvidia-docker/issues/1399))
- All containers require NVIDIA Docker runtime (`--gpus all` flag when running)
- For H100 GPUs: Use CPU relaxation mode (`--use_gpu_relax=false`) due to OpenMM PTX compatibility issues
- Apptainer definitions tested on ALCF systems with comprehensive validation
- Layered approach provides 90% build time reduction for development workflows
- Unified containers include comprehensive integration testing via built-in test applications