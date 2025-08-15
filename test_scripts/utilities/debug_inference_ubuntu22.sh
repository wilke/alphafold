#!/bin/bash
# Debug inference script for Ubuntu 22.04

set -e

TEST_BASE="/scratch/alphafold"
CONTAINERS_DIR="$TEST_BASE/containers"
UBUNTU22_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu22_fixed.sif"
DB_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases"

# Use smallest preprocessed features
FEATURES_DIR="/scratch/alphafold_split_pipeline_test/output/1VII"

echo "=== Debug Inference Test - Ubuntu 22.04 ==="
echo "Testing single inference with 1VII on Ubuntu 22.04 (CUDNN 8.9.6)"

echo "Checking inputs:"
echo "  Features: $(ls -lah $FEATURES_DIR/features.pkl)"
echo "  Container: $(ls -lah $UBUNTU22_CONTAINER | cut -d' ' -f5-)"
echo "  Params: $(ls -lah $DB_DIR/params/ | wc -l) files"

echo
echo "Running inference..."

# Create proper directory structure for inference script
INFERENCE_INPUT="/scratch/alphafold/inference_input_ubuntu22"
mkdir -p "$INFERENCE_INPUT/1VII"
cp "$FEATURES_DIR/features.pkl" "$INFERENCE_INPUT/1VII/features.pkl"

time apptainer exec --nv \
    --bind "$INFERENCE_INPUT:/input" \
    --bind "$DB_DIR/params:/data/params:ro" \
    "$UBUNTU22_CONTAINER" \
    python /app/alphafold/run_alphafold_inference.py \
    --output_dir=/input \
    --data_dir=/data \
    --target_names=1VII \
    --model_preset=monomer \
    --use_gpu_relax=false

echo
echo "Results:"
ls -lah "$INFERENCE_INPUT/1VII/" | head -10

if [ -f "$INFERENCE_INPUT/1VII/timings.json" ]; then
    echo "\nTiming data:"
    cat "$INFERENCE_INPUT/1VII/timings.json"
fi