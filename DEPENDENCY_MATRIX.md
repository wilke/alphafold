# Unified Container Dependency Compatibility Matrix

## Overview

This matrix analyzes compatibility between AlphaFold, Patrick Runtime, and BV-BRC service framework dependencies to identify potential conflicts and resolution strategies.

## Component Dependency Analysis

### AlphaFold v2.3.2 Core Dependencies

| Component | Version | Source | Purpose | Conflicts |
|-----------|---------|--------|---------|-----------|
| Python | 3.11 | Conda | Runtime environment | ✅ None |
| JAX | 0.4.26 | PyPI | Neural network computation | ⚠️ CUDA version sensitive |
| JAXlib | 0.4.26+cuda12.cudnn89 | PyPI | CUDA backend for JAX | ⚠️ CUDNN version specific |
| TensorFlow | latest | PyPI | ML framework | ✅ Compatible with JAX |
| NumPy | latest | Conda | Numerical computing | ✅ Managed by JAX |
| OpenMM | 8.0.0 | Conda-forge | Structure relaxation | ❌ H100 PTX issue |
| BioPython | latest | PyPI | Sequence handling | ✅ None |
| HHsuite | 3.3.0 | Source | MSA generation | ✅ None |
| HMMER | system | apt | Sequence search | ✅ None |
| Kalign | system | apt | Multiple alignment | ✅ None |

### Patrick Runtime Dependencies

| Component | Version | Source | Purpose | Conflicts |
|-----------|---------|--------|---------|-----------|
| Perl | 5.34 | System | Scripting runtime | ✅ None |
| Python | 3.x | System/Scripts | Tool scripting | ⚠️ Version consistency |
| CoreSNP | git-3eab846 | Archive | SNP analysis | ✅ None |
| KronaTools | v2.8.1 | Archive | Visualization | ✅ None |
| FastQC | 0.12.1 | Archive | Quality control | ✅ None |
| R | 4.2.3 | Archive | Statistical analysis | ⚠️ Path conflicts |
| bcftools | 1.17 | Archive | Variant calling | ✅ None |
| antismash | 7.1.0 | Archive | Secondary metabolites | ⚠️ Python deps |

### BV-BRC Framework Dependencies

| Component | Version | Source | Purpose | Conflicts |
|-----------|---------|--------|---------|-----------|
| Bio::KBase::AppService | latest | CPAN | Service framework | ✅ None |
| File::Slurp | latest | CPAN | File operations | ✅ None |
| JSON | latest | CPAN | Data serialization | ✅ None |
| Data::Dumper | core | Perl | Debugging | ✅ None |
| BioPerl | latest | CPAN | Biological sequences | ✅ None |
| LWP::UserAgent | latest | CPAN | HTTP client | ✅ None |

## Conflict Analysis and Resolutions

### 1. CUDA/GPU Compatibility

**Issue**: Multiple CUDA-dependent components with version requirements

| Component | CUDA Requirement | Resolution |
|-----------|------------------|------------|
| JAX 0.4.26 | CUDA 12.2 | ✅ Use nvidia/cuda:12.2.2-cudnn8-devel base |
| JAXlib | CUDNN 8.9 | ✅ Ubuntu 22.04 symlink fixes |
| OpenMM | PTX compilation | ❌ Use `--use_gpu_relax=false` for H100 |
| TensorFlow | CUDA 12.x | ✅ Auto-detects compatible version |

**Resolution Strategy**:
```bash
# CUDNN symlink fixes for Ubuntu 22.04
for lib in libcudnn libcudnn_adv_infer libcudnn_adv_train; do
    ln -sf ${lib}.so.8.9.7 ${lib}.so.8
done
```

### 2. Python Environment Conflicts

**Issue**: Multiple Python interpreters and package requirements

| Source | Python Location | Package Manager | Resolution |
|--------|----------------|-----------------|------------|
| AlphaFold | /opt/conda/bin/python | conda + pip | ✅ Primary environment |
| Patrick Tools | Various scripts | mixed | ✅ Use system python for scripts |
| System | /usr/bin/python | apt | ✅ Symlinked to python3 |

**Resolution Strategy**:
```bash
# Unified Python environment
export PATH="/opt/conda/bin:$PATH"  # Conda takes precedence
export PYTHONNOUSERSITE=1           # Prevent user package conflicts
# Patrick scripts use explicit shebangs or env python
```

### 3. Perl Module Compatibility

**Issue**: BV-BRC framework requires specific Perl modules

| Module | AlphaFold Need | Patrick Need | BV-BRC Need | Resolution |
|--------|----------------|--------------|-------------|------------|
| BioPerl | ❌ No | ✅ Yes | ✅ Yes | ✅ Install via CPAN |
| File::Slurp | ❌ No | ⚠️ Maybe | ✅ Yes | ✅ Install via CPAN |
| JSON | ❌ No | ✅ Yes | ✅ Yes | ✅ Install via CPAN |
| Statistics::* | ❌ No | ✅ Yes | ⚠️ Maybe | ✅ Install via CPAN |

**Resolution Strategy**:
```bash
# Install all required Perl modules with force flag
cpanm --notest --force Bio::KBase::AppService::AppScript File::Slurp JSON BioPerl
```

### 4. Binary Name Conflicts

**Issue**: Tool name collisions between different packages

| Binary Name | AlphaFold | Patrick | System | Resolution |
|-------------|-----------|---------|--------|------------|
| python | /opt/conda/bin | various scripts | /usr/bin | ✅ PATH precedence |
| perl | ❌ No | scripts | /usr/bin | ✅ No conflict |
| R | ❌ No | /opt/patric.../R-4.2.3 | apt package | ✅ Patrick PATH |
| bcftools | ❌ No | /opt/patric.../bcftools | apt package | ⚠️ Version difference |

**Resolution Strategy**:
```bash
# PATH management with clear precedence
export PATH="/opt/conda/bin:/opt/hhsuite/bin:/opt/patric-common/bin:$PATH"
```

### 5. Library Version Conflicts

**Issue**: Shared library version requirements

| Library | AlphaFold Requirement | Patrick Requirement | Resolution |
|---------|----------------------|-------------------|------------|
| CUDA | 12.2.x | Not directly used | ✅ No conflict |
| GLIBC | 2.35+ (Ubuntu 22.04) | 2.31+ | ✅ Compatible |
| OpenSSL | System version | System version | ✅ Shared |
| zlib | System version | System version | ✅ Shared |

## Environment Variable Management

### 1. Core Environment Setup

```bash
# AlphaFold Core
export PYTHONPATH="/app/alphafold:$PYTHONPATH"
export CUDA_HOME="/usr/local/cuda-12.2"
export CUDNN_PATH="/usr/lib/x86_64-linux-gnu"

# Patrick Runtime
export PATRIC_RUNTIME="/opt/patric-common/runtime"
export PERL5LIB="/opt/patric-common/runtime/lib:$PERL5LIB"

# BV-BRC Framework (inherits Patrick + Perl)
export BVBRC_SERVICES="/app/bvbrc-services"
```

### 2. PATH Precedence Strategy

```bash
# Highest to lowest priority
/opt/conda/bin          # AlphaFold Python environment
/opt/hhsuite/bin        # AlphaFold tools
/opt/patric-common/bin  # Patrick tools (unified)
/usr/local/bin          # User-installed tools
/usr/bin                # System tools
/bin                    # Core system binaries
```

### 3. Tool-Specific Environments

```bash
# KronaTools
export KRONA_TOOLS="$PATRIC_RUNTIME/KronaTools-v2.8.1"

# AntiSMASH
export ANTISMASH_HOME="$PATRIC_RUNTIME/antismash-7-1-0-1"

# R environment (if used)
export R_HOME="$PATRIC_RUNTIME/R-4.2.3"
export R_LIBS="$R_HOME/lib/R/library"
```

## Testing Matrix

### 1. Component Isolation Tests

| Test | Purpose | Command | Expected Result |
|------|---------|---------|-----------------|
| AlphaFold Import | Verify core ML stack | `python -c "import alphafold"` | No errors |
| JAX GPU Detection | GPU acceleration | `python -c "import jax; print(jax.devices())"` | GPU devices listed |
| Patrick Tools | Tool availability | `ls /opt/patric-common/bin/` | Tool list |
| Perl Modules | BV-BRC framework | `perl -e "use Bio::KBase::AppService"` | No errors |

### 2. Integration Tests

| Test | Purpose | Command | Expected Result |
|------|---------|---------|-----------------|
| Path Resolution | No conflicts | `which python perl` | Correct paths |
| Environment Vars | Proper setup | `printenv \| grep PATRIC` | Variables set |
| Cross-component | Tools work together | AlphaFold + Patrick workflow | Success |

### 3. Performance Tests

| Test | Purpose | Measurement | Acceptable Range |
|------|---------|-------------|------------------|
| Container Startup | Overhead | Time to prompt | < 10 seconds |
| AlphaFold Import | Python overhead | Import time | < 30 seconds |
| Memory Usage | Baseline consumption | RSS memory | < 2GB idle |

## Known Issues and Workarounds

### 1. H100 GPU Compatibility

**Issue**: OpenMM lacks PTX for compute capability 9.0
```bash
# Workaround: Use CPU relaxation
--use_gpu_relax=false
```

**Impact**: <5% performance penalty for AlphaFold total runtime

### 2. Container Size

**Issue**: Large container (~11GB) due to multiple toolchains
```bash
# Mitigation: Aggressive cleanup
rm -rf /var/lib/apt/lists/* /tmp/* /opt/conda/pkgs/cache/
```

### 3. Build Time

**Issue**: Long build times (45-60 minutes) due to complexity
```bash
# Mitigation: Layer optimization and caching
# Separate frequently-changing components
```

## Validation Checklist

### Pre-Build Validation
- [ ] patric.tar contains expected runtime structure
- [ ] AlphaFold source code is complete
- [ ] System has sufficient disk space (15GB+)
- [ ] Apptainer/Singularity is available

### Post-Build Validation
- [ ] Container builds without errors
- [ ] All three test suites pass
- [ ] GPU detection works (if available)
- [ ] Patrick tools are accessible
- [ ] BV-BRC Perl modules load correctly

### Runtime Validation
- [ ] AlphaFold help displays correctly
- [ ] Patrick environment wrapper works
- [ ] BV-BRC service framework responds
- [ ] No PATH conflicts detected
- [ ] Environment variables properly set

## Maintenance Guidelines

### 1. Version Updates

**AlphaFold Updates**:
- JAX version changes require CUDA compatibility verification
- Test OpenMM compatibility with new GPU architectures
- Validate TensorFlow integration

**Patrick Updates**:
- New patric.tar requires full tool inventory
- Check for new Perl module dependencies
- Validate tool symlinks after extraction

**System Updates**:
- Ubuntu LTS upgrades need CUDA driver validation
- CUDNN updates require symlink fixes
- Perl version changes need module recompilation

### 2. Performance Monitoring

**Build Performance**:
- Track build times for optimization opportunities
- Monitor container size growth
- Identify caching improvements

**Runtime Performance**:
- Benchmark AlphaFold prediction times
- Monitor GPU utilization efficiency
- Track memory usage patterns

This dependency matrix provides a comprehensive foundation for maintaining compatibility across all three integrated components while enabling efficient troubleshooting and optimization.