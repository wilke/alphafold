#!/bin/bash
# Test script for AlphaFold Apptainer containers
# Uses the production definitions and current best practices

set -e

# Configuration
CONTAINER="${1:-alphafold_ubuntu20.sif}"
TEST_FASTA="${2:-test.fasta}"
OUTPUT_DIR="${3:-test_output_$(date +%Y%m%d_%H%M%S)}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== AlphaFold Container Test ==="
echo "Container: $CONTAINER"
echo "Test sequence: $TEST_FASTA"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo -e "${RED}Error: Container $CONTAINER not found${NC}"
    echo "Build it first with: apptainer build --fakeroot $CONTAINER alphafold_ubuntu20.def"
    exit 1
fi

# Create test sequence if it doesn't exist
if [ ! -f "$TEST_FASTA" ]; then
    echo "Creating test sequence..."
    cat > "$TEST_FASTA" << EOF
>test_protein
MKILLITIGTVLAVFTVFGIFNSVSAQKDNFGLTGGDVDQGFGQIRSDQTRDLVRKPKAAAKLL
EOF
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Test 1: Check container dependencies
echo "=== Test 1: Checking Dependencies ==="
apptainer exec --nv "$CONTAINER" python -c "
import sys
print(f'Python: {sys.version}')
try:
    import jax
    print(f'✓ JAX {jax.__version__}')
    devices = jax.devices()
    print(f'  Devices: {devices}')
    
    import tensorflow as tf
    print(f'✓ TensorFlow {tf.__version__}')
    
    import alphafold
    print('✓ AlphaFold module')
    
    import openmm
    print(f'✓ OpenMM {openmm.__version__}')
    
    print('\nAll dependencies loaded successfully!')
except Exception as e:
    print(f'✗ Error: {e}')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencies test passed${NC}"
else
    echo -e "${RED}✗ Dependencies test failed${NC}"
    exit 1
fi

# Test 2: GPU Detection
echo ""
echo "=== Test 2: GPU Detection ==="
apptainer exec --nv "$CONTAINER" nvidia-smi -L

# Test 3: Run AlphaFold (minimal test)
echo ""
echo "=== Test 3: Running AlphaFold ==="
echo "Note: This will use CPU relaxation on H100 systems"

# Determine if we're on H100
GPU_TYPE=$(apptainer exec --nv "$CONTAINER" nvidia-smi -L | head -1)
if [[ "$GPU_TYPE" == *"H100"* ]]; then
    echo "H100 detected - using CPU relaxation"
    GPU_RELAX="false"
else
    echo "Non-H100 GPU - using GPU relaxation"
    GPU_RELAX="true"
fi

# Run AlphaFold
apptainer run --nv "$CONTAINER" \
    --fasta_paths="$TEST_FASTA" \
    --max_template_date=2022-01-01 \
    --db_preset=reduced_dbs \
    --model_preset=monomer \
    --use_gpu_relax="$GPU_RELAX" \
    --data_dir=/path/to/alphafold/databases \
    --output_dir="$OUTPUT_DIR" \
    --benchmark=false

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ AlphaFold test completed${NC}"
    echo ""
    echo "Output files:"
    ls -la "$OUTPUT_DIR"/test_protein/
else
    echo -e "${RED}✗ AlphaFold test failed${NC}"
    exit 1
fi

echo ""
echo "=== All Tests Passed ==="
echo "Container is ready for production use!"