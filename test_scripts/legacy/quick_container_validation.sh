#!/bin/bash
# Quick validation of both Ubuntu containers

set -e

TEST_BASE="/scratch/alphafold"
CONTAINERS_DIR="$TEST_BASE/containers"
UBUNTU20_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu20.sif"
UBUNTU22_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu22.sif"

echo "=== Quick Container Validation ==="
echo "Testing both Ubuntu 20.04 and Ubuntu 22.04 (CUDNN 8.9.6 fix)"
echo

# Test CUDNN directly in both containers
echo "1. Testing CUDNN initialization..."

# Create test script
cat > /scratch/test_cudnn_quick.py << 'EOF'
import ctypes
try:
    cudnn = ctypes.CDLL("libcudnn.so.8")
    get_version = cudnn.cudnnGetVersion
    get_version.restype = ctypes.c_size_t
    version = get_version()
    major = version // 1000
    minor = (version % 1000) // 100
    patch = version % 100
    print(f"CUDNN {major}.{minor}.{patch}")
    
    handle = ctypes.c_void_p()
    create = cudnn.cudnnCreate
    create.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
    create.restype = ctypes.c_int
    status = create(ctypes.byref(handle))
    
    if status == 0:
        print("✓ CUDNN handle created successfully")
        cudnn.cudnnDestroy(handle)
    else:
        print(f"✗ CUDNN failed with status: {status}")
except Exception as e:
    print(f"✗ Error: {e}")
EOF

echo "Ubuntu 20.04 CUDNN test:"
apptainer exec --nv --bind /scratch:/scratch "$UBUNTU20_CONTAINER" python3 /scratch/test_cudnn_quick.py

echo "Ubuntu 22.04 CUDNN test:"
apptainer exec --nv --bind /scratch:/scratch "$UBUNTU22_CONTAINER" python3 /scratch/test_cudnn_quick.py

echo
echo "2. Testing JAX GPU detection..."

# Create JAX test
cat > /scratch/test_jax_quick.py << 'EOF'
import jax
import jax.numpy as jnp
print(f"JAX version: {jax.__version__}")
devices = jax.devices()
print(f"Devices: {len(devices)} GPU(s)")
if devices:
    x = jnp.array([1.0, 2.0, 3.0])
    print(f"✓ JAX array created: {x}")
else:
    print("✗ No GPUs detected")
EOF

echo "Ubuntu 20.04 JAX test:"
apptainer exec --nv --bind /scratch:/scratch "$UBUNTU20_CONTAINER" python3 /scratch/test_jax_quick.py

echo "Ubuntu 22.04 JAX test:"
apptainer exec --nv --bind /scratch:/scratch "$UBUNTU22_CONTAINER" python3 /scratch/test_jax_quick.py

echo
echo "3. Container info comparison:"
echo "Ubuntu 20.04:"
apptainer exec "$UBUNTU20_CONTAINER" cat /etc/os-release | grep PRETTY_NAME

echo "Ubuntu 22.04:"
apptainer exec "$UBUNTU22_CONTAINER" cat /etc/os-release | grep PRETTY_NAME

echo
echo "✓ Quick validation complete!"
echo "Both containers should show:"
echo "  - CUDNN handle creation: SUCCESS"
echo "  - JAX: 8 GPU devices detected"
echo "  - No initialization errors"

# Cleanup
rm -f /scratch/test_cudnn_quick.py /scratch/test_jax_quick.py