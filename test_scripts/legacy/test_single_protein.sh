#!/bin/bash
# Test single protein on both containers

set -e

TEST_BASE="/scratch/alphafold"
CONTAINERS_DIR="$TEST_BASE/containers"
SEQUENCES_DIR="$TEST_BASE/test_sequences"
OUTPUTS_DIR="$TEST_BASE/test_outputs"
DB_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases"

UBUNTU20_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu20.sif"
UBUNTU22_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu22.sif"

# Test with smallest protein
PROTEIN="1UBQ"  # 76 amino acids

echo "=== Single Protein Test: $PROTEIN ==="
echo "Testing both containers with $PROTEIN (76 aa)"
echo

# Create output directories
mkdir -p "$OUTPUTS_DIR/ubuntu20/$PROTEIN"
mkdir -p "$OUTPUTS_DIR/ubuntu22/$PROTEIN"

# Function to run test
run_single_test() {
    local container=$1
    local container_name=$2
    local output_subdir=$3
    
    echo "Testing $container_name..."
    
    local fasta_file="$SEQUENCES_DIR/$PROTEIN.fasta"
    local output_dir="$OUTPUTS_DIR/$output_subdir/$PROTEIN"
    
    local start_time=$(date +%s)
    
    timeout 900 apptainer run --nv \
        --bind "$fasta_file:/input.fasta:ro" \
        --bind "$output_dir:/output" \
        --bind "$DB_DIR:/data:ro" \
        "$container" \
        --fasta_paths=/input.fasta \
        --output_dir=/output \
        --model_preset=monomer \
        --db_preset=reduced_dbs \
        --max_template_date=2022-01-01 \
        --use_gpu_relax=false \
        --data_dir=/data \
        --uniref90_database_path=/data/uniref90/uniref90.fasta \
        --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa \
        --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
        --pdb70_database_path=/data/pdb70/pdb70 \
        --bfd_database_path=/data/small_bfd/bfd-first_non_consensus_sequences.fasta
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ $container_name: SUCCESS (${duration}s)"
        
        # Check outputs
        local ranked_pdb="$output_dir/$PROTEIN/ranked_0.pdb"
        if [ -f "$ranked_pdb" ]; then
            local pdb_size=$(wc -c < "$ranked_pdb")
            echo "  - PDB size: ${pdb_size} bytes"
            echo "  - First 3 lines:"
            head -3 "$ranked_pdb" | sed 's/^/    /'
        fi
        
        local timings_file="$output_dir/$PROTEIN/timings.json"
        if [ -f "$timings_file" ]; then
            echo "  - Timings available"
        fi
        
        return 0
    else
        echo "✗ $container_name: FAILED (exit code: $exit_code, ${duration}s)"
        return 1
    fi
}

echo "Starting tests..."
echo

# Test Ubuntu 20.04
echo "=== Ubuntu 20.04 Test ==="
run_single_test "$UBUNTU20_CONTAINER" "Ubuntu 20.04" "ubuntu20"
ubuntu20_result=$?

echo
echo "=== Ubuntu 22.04 Test ==="
run_single_test "$UBUNTU22_CONTAINER" "Ubuntu 22.04 (CUDNN 8.9.6)" "ubuntu22"
ubuntu22_result=$?

echo
echo "=== Results Summary ==="
if [ $ubuntu20_result -eq 0 ]; then
    echo "✓ Ubuntu 20.04: PASS"
else
    echo "✗ Ubuntu 20.04: FAIL"
fi

if [ $ubuntu22_result -eq 0 ]; then
    echo "✓ Ubuntu 22.04: PASS"
else
    echo "✗ Ubuntu 22.04: FAIL"
fi

if [ $ubuntu20_result -eq 0 ] && [ $ubuntu22_result -eq 0 ]; then
    echo
    echo "🎉 Both containers working! Ubuntu 22.04 CUDNN fix successful."
    exit 0
else
    echo
    echo "❌ One or more containers failed."
    exit 1
fi