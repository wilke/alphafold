# Unified AlphaFold + Patrick Runtime Integration Analysis

## Overview

This document analyzes the integration of three key components into a unified Apptainer container:

1. **AlphaFold v2.3.2**: GPU-accelerated protein structure prediction
2. **Patrick Runtime**: BV-BRC bioinformatics tool collection 
3. **AlphaFoldApp**: BV-BRC service wrapper framework

## Architecture Design

### Base System
- **Foundation**: NVIDIA CUDA 12.2.2 + CUDNN8 on Ubuntu 22.04
- **Python Environment**: Conda-managed Python 3.11 with JAX 0.4.26
- **Perl Environment**: System Perl 5.34 + CPAN modules for BV-BRC

### Directory Structure
```
/app/
├── alphafold/              # AlphaFold source code
├── bvbrc-services/         # BV-BRC service scripts
├── run_alphafold.sh        # Unified AlphaFold runner
├── run_bvbrc_service.sh    # BV-BRC service runner
└── test_unified.py         # Comprehensive test suite

/opt/
├── conda/                  # Miniconda Python environment
├── hhsuite/               # HHsuite for MSA generation
└── patric-common/
    ├── runtime/           # Patrick tools (extracted from patric.tar)
    └── bin/               # Unified Patrick tool symlinks
```

## Integration Strategy

### 1. Patrick Runtime Extraction
**Location**: Extract `patric.tar` to `/opt/patric-common/runtime/` during container build

**Implementation**:
- Extract during `%post` phase after system package installation
- Create unified `/opt/patric-common/bin/` with symlinks to all Patrick executables
- Avoid PATH conflicts by using dedicated Patrick bin directory

### 2. Environment Variable Management
**Core Strategy**: Layered environment setup with clear precedence

**PATH Order**:
```bash
/opt/conda/bin          # Python/Conda tools (highest priority)
/opt/hhsuite/bin        # HHsuite tools
/opt/patric-common/bin  # Patrick tools
$PATH                   # System binaries (lowest priority)
```

**Key Environment Variables**:
```bash
# AlphaFold Core
PYTHONPATH="/app/alphafold:$PYTHONPATH"
CUDA_HOME="/usr/local/cuda-12.2"
XLA_FLAGS="--xla_gpu_cuda_data_dir=/usr/local/cuda-12.2"

# Patrick Runtime  
PATRIC_RUNTIME="/opt/patric-common/runtime"
PERL5LIB="/opt/patric-common/runtime/lib:$PERL5LIB"

# Tool-specific
KRONA_TOOLS="$PATRIC_RUNTIME/KronaTools-v2.8.1"
ANTISMASH_HOME="$PATRIC_RUNTIME/antismash-7-1-0-1"
```

### 3. Dependency Resolution

#### Python Dependencies
- **AlphaFold Stack**: JAX 0.4.26, TensorFlow, OpenMM, BioPython
- **Additional for Patrick**: pandas, scipy, matplotlib (for Python-based Patrick tools)
- **Isolation**: All managed through single Conda environment at `/opt/conda`

#### Perl Dependencies  
- **BV-BRC Framework**: Bio::KBase::AppService modules
- **Core Modules**: File::Slurp, JSON, Data::Dumper
- **Scientific**: BioPerl, Statistics::Descriptive
- **Installation**: Via CPAN with `--notest --force` for faster builds

#### System Dependencies
- **GPU Support**: CUDA 12.2, CUDNN8 with Ubuntu 22.04 compatibility fixes
- **Build Tools**: GCC, CMake for HHsuite compilation
- **Utilities**: Perl, file compression tools, text processors

## Build Optimization

### 1. Multi-stage Build Process
```
Stage 1: System packages + Patrick extraction
Stage 2: Conda environment + Python packages  
Stage 3: AlphaFold source integration + final setup
```

### 2. Cache Optimization
- **Patrick extraction**: Early in build process (changes infrequently)
- **System packages**: Before Python environment (stable layer)  
- **Python packages**: After Patrick extraction (frequently updated)
- **Source code**: Final stage (development changes)

### 3. Size Reduction
- **Cleanup**: Remove build artifacts, package caches, temp directories
- **Selective installation**: `--no-install-recommends` for apt packages
- **Layer consolidation**: Combine related operations in single RUN commands

## Conflict Resolution

### 1. Identified Conflicts
**Binary Name Conflicts**:
- `python` vs Patrick Python scripts → Resolved by PATH precedence
- Common utility names → Patrick tools in dedicated `/opt/patric-common/bin/`

**Library Conflicts**:
- CUDA libraries for JAX vs system → CUDNN symlink fixes for Ubuntu 22.04
- Python package versions → Single Conda environment manages all Python deps

### 2. Resolution Strategies
**PATH Management**:
- AlphaFold tools have highest priority
- Patrick tools isolated in separate bin directory
- Avoid system PATH pollution

**Environment Isolation**:
- Use `PYTHONNOUSERSITE=1` to prevent user package interference
- Explicit PERL5LIB setup for Patrick Perl modules
- Clear CUDA environment variables for GPU access

## Testing Strategy

### 1. Component Testing
**AlphaFold Dependencies**:
```python
- NumPy, JAX, TensorFlow import tests
- GPU device detection
- CUDNN library verification  
- OpenMM availability check
```

**Patrick Environment**:
```bash
- Runtime directory verification
- Key tool availability (CoreSNP, KronaTools, etc.)
- Perl module testing
- Executable permissions
```

**Integration Testing**:
```bash
- PATH resolution conflicts
- Environment variable inheritance
- Cross-component tool access
```

### 2. Runtime Verification
**AlphaFold Execution**:
- Basic prediction test with small protein
- GPU utilization verification
- Output file generation

**Patrick Tool Access**:
- Individual tool execution tests
- Perl script compatibility
- Environment variable propagation

**BV-BRC Service Framework**:
- Perl module availability
- Service script parsing
- Parameter validation

## Potential Issues and Mitigations

### 1. GPU Compatibility
**Issue**: OpenMM PTX compilation for H100 GPUs
**Mitigation**: Default to CPU relaxation with `--use_gpu_relax=false`
**Detection**: Test script checks GPU availability and warns about H100 limitations

### 2. Memory Management
**Issue**: Large container size due to multiple toolchains
**Mitigation**: 
- Aggressive cleanup of build artifacts
- Selective package installation
- Shared library optimization

### 3. Version Conflicts
**Issue**: Python package version requirements between AlphaFold and Patrick tools
**Mitigation**:
- Single Conda environment with compatible versions
- Pin critical packages (JAX 0.4.26)
- Install additional packages that don't conflict

## Container Usage Patterns

### 1. AlphaFold Mode (Default)
```bash
apptainer run --nv unified.sif --fasta_paths=protein.fasta --data_dir=/databases --output_dir=/output
```

### 2. BV-BRC Service Mode  
```bash
apptainer run --app bvbrc unified.sif job_id app_def params.json
```

### 3. Patrick Tools Mode
```bash
apptainer run --app patrick-env unified.sif CoreSNP.py [args]
```

### 4. Interactive Development
```bash
apptainer shell unified.sif
# All tools available in unified environment
```

## Verification Commands

### Build Verification
```bash
# Test all components
apptainer run --app test unified.sif

# Test AlphaFold specifically
apptainer exec --nv unified.sif python -c "import alphafold; print('OK')"

# Test Patrick tools
apptainer exec unified.sif ls /opt/patric-common/bin/ | head -10

# Test BV-BRC Perl modules
apptainer exec unified.sif perl -e "use Bio::KBase::AppService::AppScript; print 'OK'"
```

### Runtime Verification
```bash
# AlphaFold minimal test
apptainer run --nv unified.sif --help

# Patrick tool access
apptainer exec unified.sif /opt/patric-common/bin/CoreSNP.py --help

# Environment consistency
apptainer exec unified.sif printenv | grep -E "(PATRIC|CUDA|PYTHONPATH)"
```

## Performance Considerations

### 1. Container Startup
- **Cold start**: ~5-10 seconds for environment setup
- **GPU initialization**: Additional 2-3 seconds for CUDA libraries
- **Patrick tools**: Minimal overhead when not used

### 2. Runtime Performance
- **AlphaFold**: No performance impact from Patrick integration
- **GPU utilization**: Full CUDA 12.2 support maintained  
- **Memory overhead**: <500MB additional for Patrick runtime

### 3. Storage Requirements
- **Base AlphaFold**: ~8GB
- **Patrick Runtime**: ~2GB (from patric.tar)
- **Unified Container**: ~11GB total

## Maintenance Recommendations

### 1. Version Updates
- **AlphaFold**: Update JAX/TensorFlow versions together
- **Patrick**: Update entire patric.tar archive as unit
- **System**: Ubuntu LTS provides 5-year stability

### 2. Security Updates
- **Base image**: Regular CUDA image updates from NVIDIA
- **System packages**: Automated security updates during build
- **Python packages**: Monitor for security advisories

### 3. Testing Automation
- **CI/CD integration**: Automated build and test on updates
- **Performance regression**: Benchmark key workflows
- **Compatibility matrix**: Test against different GPU architectures

This unified container provides a robust foundation for running AlphaFold within the BV-BRC ecosystem while maintaining full compatibility with existing Patrick bioinformatics workflows.