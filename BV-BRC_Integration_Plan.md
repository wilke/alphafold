# BV-BRC dev_container + AlphaFoldApp Integration Plan

## Executive Summary

This plan outlines the integration of BV-BRC dev_container environment and AlphaFoldApp service into our unified AlphaFold + Patric container, moving from external mounting to proper internal integration.

## Current State vs Target State

### Current State (External Mounting)
```bash
# Current approach requires external mounts
apptainer shell --writable-tmpfs \
  --bind `pwd`/dev_container:/dev_container \
  --bind `pwd`/AlphaFoldApp:/AlphaFoldApp \
  images/alphafold_unified_patric.sif
```

### Target State (Internal Integration)
```bash
# Target: Fully integrated container
apptainer run --app bvbrc alphafold_unified_patric.sif job_id app_def.json params.json
```

## Integration Architecture

### Layered Integration Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    Unified Container                        │
├─────────────────────────────────────────────────────────────┤
│                    Application Layer                        │
│ ┌─────────────────────┬─────────────────────────────────────┐ │
│ │ AlphaFoldApp Module │ BV-BRC Service Framework            │ │
│ │ - App-AlphaFold.pl  │ - Job scheduling                    │ │
│ │ - Parameter specs   │ - Workspace integration             │ │
│ │ - Test configs      │ - Authentication                    │ │
│ └─────────────────────┴─────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                 BV-BRC Runtime Layer                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ dev_container Environment                               │ │
│ │ - Core BV-BRC modules (p3_auth, app_service, etc.)     │ │
│ │ - Perl/Python/R runtime libraries                      │ │
│ │ - Build system (bootstrap, makefiles)                  │ │
│ │ - Environment setup (user-env.sh)                      │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│              Scientific Computing Layer                     │
│ ┌─────────────────────┬─────────────────────────────────────┐ │
│ │ AlphaFold v2.3.2    │ Patric Runtime                      │ │
│ │ - JAX, TensorFlow   │ - 70GB toolchain                    │ │
│ │ - OpenMM, BioPython │ - CoreSNP, KronaTools               │ │
│ │ - Structure predict │ - Bioinformatics utilities          │ │
│ └─────────────────────┴─────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Base System                              │
│                Ubuntu 22.04 + CUDA 12.2.2                  │
└─────────────────────────────────────────────────────────────┘
```

## Integration Strategy

### Phase 1: Container Structure Redesign

#### 1.1 Directory Layout
```
/app/
├── alphafold/                    # AlphaFold core (existing)
├── patric-common/               # Patric runtime (existing)
│   └── runtime/
├── bvbrc/                       # New: BV-BRC integration
│   ├── dev_container/           # Full dev_container environment
│   │   ├── modules/             # BV-BRC core modules
│   │   │   ├── AlphaFoldApp/    # AlphaFoldApp service
│   │   │   ├── p3_auth/         # Authentication
│   │   │   ├── app_service/     # Application framework
│   │   │   ├── p3_cli/          # Command line tools
│   │   │   └── Workspace/       # File management
│   │   ├── bin/                 # Compiled binaries
│   │   ├── lib/                 # Runtime libraries
│   │   └── user-env.sh          # Environment setup
│   └── runtime -> ../patric-common/runtime  # Symlink to Patric runtime
```

#### 1.2 Build Process Integration
```bash
# During container build
%post
    # ... existing AlphaFold + Patric setup ...
    
    # Clone and setup dev_container
    cd /app/bvbrc
    git clone https://github.com/BV-BRC/dev_container.git
    cd dev_container
    
    # Clone AlphaFoldApp into modules directory
    mkdir -p modules
    cd modules
    git clone /path/to/AlphaFoldApp
    
    # Setup BV-BRC environment
    cd /app/bvbrc/dev_container
    ./checkout-bvbrc-modules
    ./bootstrap /opt/patric-common/runtime
    source user-env.sh
    make
```

### Phase 2: Path and Configuration Updates

#### 2.1 AlphaFoldApp Service Configuration
**File**: `/app/bvbrc/dev_container/modules/AlphaFoldApp/service-scripts/App-AlphaFold.pl`

**Required Modifications**:
```perl
# OLD: External container reference
my $default_image = "/alphafold/images/alphafold_latest.sif";
my @cmd = ("apptainer", "run", "-B", "/alphafold/databases:/databases");

# NEW: Self-contained approach
my $default_image = "self";  # Use current container
my @cmd = ("python", "/app/alphafold/run_alphafold.py");
```

#### 2.2 Database Path Configuration
```perl
# Update database path mapping
# OLD: External mount
"-B", "/alphafold/databases:/databases"

# NEW: Use container mount or host database
"-B", "/home/wilke/databases:/databases"
```

#### 2.3 Environment Integration
```bash
# Create unified environment setup
cat > /app/bvbrc/setup_bvbrc_env.sh << 'EOF'
#!/bin/bash
# Integrate BV-BRC with existing container environment
source /app/bvbrc/dev_container/user-env.sh

# Override paths for container integration
export KB_TOP="/app/bvbrc/dev_container"
export KB_RUNTIME="/opt/patric-common/runtime"

# Integrate with existing Patric environment
source /opt/patric-common/setup_patric_env.sh

# Set AlphaFold integration paths
export ALPHAFOLD_CONTAINER_SELF="true"
export ALPHAFOLD_PYTHON_PATH="/app/alphafold"
export ALPHAFOLD_DATA_DIR="/databases"
EOF
```

### Phase 3: Container Application Updates

#### 3.1 Enhanced BV-BRC App
```apptainer
%apprun bvbrc
    # Setup integrated BV-BRC environment
    source /app/bvbrc/setup_bvbrc_env.sh
    
    # Execute BV-BRC AlphaFold service
    exec perl /app/bvbrc/dev_container/modules/AlphaFoldApp/service-scripts/App-AlphaFold.pl "$@"
```

#### 3.2 Development and Testing Apps
```apptainer
%apprun bvbrc-dev
    # Interactive development environment
    source /app/bvbrc/setup_bvbrc_env.sh
    exec /bin/bash

%apprun bvbrc-test
    # Run BV-BRC integration tests
    source /app/bvbrc/setup_bvbrc_env.sh
    cd /app/bvbrc/dev_container/modules/AlphaFoldApp
    exec make test-service
```

## Implementation Steps

### Step 1: Update Container Definition

**File**: `docker/alphafold_unified_patric.def`

**Add BV-BRC Integration Section**:
```apptainer
%post
    # ... existing setup ...
    
    # BV-BRC dev_container integration
    mkdir -p /app/bvbrc
    cd /app/bvbrc
    
    # Clone dev_container
    git clone https://github.com/BV-BRC/dev_container.git
    cd dev_container
    
    # Clone required modules
    ./checkout-bvbrc-modules
    
    # Clone AlphaFoldApp into modules directory
    cd modules
    git clone /path/to/local/AlphaFoldApp
    
    # Bootstrap with our Patric runtime
    cd /app/bvbrc/dev_container
    ./bootstrap /opt/patric-common/runtime
    
    # Source environment and build
    source user-env.sh
    make
    
    # Create integrated environment setup
    cat > /app/bvbrc/setup_bvbrc_env.sh << 'EOF'
#!/bin/bash
source /app/bvbrc/dev_container/user-env.sh
export KB_RUNTIME="/opt/patric-common/runtime"
source /opt/patric-common/setup_patric_env.sh
export ALPHAFOLD_CONTAINER_SELF="true"
export ALPHAFOLD_PYTHON_PATH="/app/alphafold"
EOF
    chmod +x /app/bvbrc/setup_bvbrc_env.sh
```

### Step 2: Modify AlphaFoldApp Service Script

**Required Changes to App-AlphaFold.pl**:
1. Detect when running inside unified container
2. Use direct AlphaFold execution instead of container-in-container
3. Adjust database paths for container environment
4. Update output collection for integrated setup

### Step 3: Update Build Scripts

**File**: `build_unified_container.sh`

Add BV-BRC validation to test suite:
```bash
# Test BV-BRC integration
log_info "Test: BV-BRC service integration..."
if apptainer run --app bvbrc-test "$CONTAINER_NAME"; then
    log_success "BV-BRC integration test passed"
else
    log_error "BV-BRC integration test failed"
    return 1
fi
```

### Step 4: Documentation Updates

Update container documentation to include:
- BV-BRC service usage patterns
- Development environment access
- Testing procedures
- Configuration options

## Validation Strategy

### Integration Testing
1. **Module Build Validation**: Ensure all BV-BRC modules build correctly
2. **Service Execution Testing**: Validate App-AlphaFold.pl works within container
3. **AlphaFold Integration**: Test direct AlphaFold execution from BV-BRC service
4. **Environment Isolation**: Ensure no conflicts between Patric and BV-BRC environments

### Performance Testing
1. **Build Time Impact**: Measure container build time increase
2. **Container Size Impact**: Monitor container size growth
3. **Runtime Performance**: Ensure no performance degradation
4. **Resource Usage**: Validate memory and CPU requirements

## Benefits of Integration

### 1. Simplified Deployment
- **Single Container**: No external mount requirements
- **Consistent Environment**: All dependencies included
- **Portable**: Easy deployment across different systems

### 2. Improved Maintainability
- **Version Control**: BV-BRC components versioned with container
- **Atomic Updates**: All components updated together
- **Testing**: Comprehensive integration testing possible

### 3. Better User Experience
- **No Setup Required**: Users don't need to manage external repositories
- **Consistent Behavior**: Same environment across all deployments
- **Reduced Complexity**: Fewer moving parts for users to manage

## Risk Mitigation

### Build Complexity
- **Risk**: Increased build complexity and time
- **Mitigation**: Layered build approach, comprehensive testing

### Container Size
- **Risk**: Significantly larger container
- **Mitigation**: Cleanup strategies, selective module inclusion

### Dependency Conflicts
- **Risk**: Conflicts between Patric and BV-BRC environments
- **Mitigation**: Careful environment separation, extensive testing

## Timeline and Milestones

1. **Week 1**: Container definition updates and basic integration
2. **Week 2**: Service script modifications and path updates
3. **Week 3**: Testing and validation
4. **Week 4**: Documentation and deployment

This integration plan provides a path from the current external mounting approach to a fully integrated container solution that includes BV-BRC dev_container environment and AlphaFoldApp service.