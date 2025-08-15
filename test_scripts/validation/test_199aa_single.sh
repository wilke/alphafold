#!/bin/bash
# Test 199aa protein individually

set -e

TEST_BASE="/scratch/alphafold/test_199aa_results"
DB_DIR="/homes/wilke/databases"
CONTAINER="/scratch/alphafold/containers/alphafold_ubuntu22.sif"
FASTA_FILE="/scratch/alphafold/test_199aa_fixed.fasta"
PROTEIN="TEST199"

echo "=== Testing 199aa Protein ==="
mkdir -p "$TEST_BASE"/{output,logs}

echo "Step 1/2: Preprocessing..."
start_time=$(date +%s)

if apptainer exec --nv \
    --bind "/scratch/alphafold:/input:ro" \
    --bind "$TEST_BASE/output:/output" \
    --bind "$DB_DIR:/data:ro" \
    "$CONTAINER" \
    python /app/alphafold/run_alphafold_preprocess.py \
    --fasta_paths="/input/test_199aa_fixed.fasta" \
    --output_dir=/output \
    --data_dir=/data \
    --uniref90_database_path=/data/uniref90/uniref90.fasta \
    --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa \
    --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --uniref30_database_path=/data/uniref30/UniRef30_2021_03 \
    --pdb70_database_path=/data/pdb70/pdb70 \
    --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
    --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
    --db_preset=full_dbs \
    --model_preset=monomer \
    --max_template_date=2022-01-01 \
    > "$TEST_BASE/logs/preprocess.log" 2>&1; then
    
    preprocess_end=$(date +%s)
    preprocess_time=$((preprocess_end - start_time))
    echo "✓ Preprocessing completed: ${preprocess_time}s ($(echo "scale=1; $preprocess_time / 60" | bc -l) min)"
    
    echo "Step 2/2: Inference..."
    inference_start=$(date +%s)
    
    if apptainer exec --nv \
        --bind "$TEST_BASE/output:/input" \
        --bind "$DB_DIR/params:/data/params:ro" \
        "$CONTAINER" \
        python /app/alphafold/run_alphafold_inference.py \
        --output_dir=/input \
        --data_dir=/data \
        --target_names="$PROTEIN" \
        --model_preset=monomer \
        --use_gpu_relax=false \
        > "$TEST_BASE/logs/inference.log" 2>&1; then
        
        inference_end=$(date +%s)
        inference_time=$((inference_end - inference_start))
        total_time=$((preprocess_time + inference_time))
        
        echo "✓ Inference completed: ${inference_time}s ($(echo "scale=1; $inference_time / 60" | bc -l) min)"
        echo "✓ Total time: ${total_time}s ($(echo "scale=1; $total_time / 60" | bc -l) min)"
        
        # Check outputs
        echo ""
        echo "=== Results ==="
        echo "Features: $(ls -lah $TEST_BASE/output/$PROTEIN/features.pkl 2>/dev/null | awk '{print $5}' || echo 'Not found')"
        echo "PDB files: $(ls -1 $TEST_BASE/output/$PROTEIN/*.pdb 2>/dev/null | wc -l)"
        
        echo ""
        echo "TEST199,199,$preprocess_time,$inference_time,$total_time,SUCCESS"
        
    else
        echo "✗ Inference failed"
        echo "TEST199,199,$preprocess_time,FAILED,$preprocess_time,INFERENCE_FAILED"
    fi
else
    echo "✗ Preprocessing failed"
    echo "Check log: $TEST_BASE/logs/preprocess.log"
    echo "TEST199,199,FAILED,SKIPPED,0,PREPROCESS_FAILED"
fi