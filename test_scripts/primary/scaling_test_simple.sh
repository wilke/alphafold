#!/bin/bash
# Simplified Ubuntu 22.04 scaling test - more robust version

set -e

# Configuration
TEST_BASE="/scratch/alphafold/scaling_test_ubuntu22_simple"
DB_DIR="/homes/wilke/databases"
CONTAINER="/scratch/alphafold/containers/alphafold_ubuntu22.sif"
SEQUENCE_DIR="/scratch/alphafold/scaling_test_sequences"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Test proteins in order of size
declare -a PROTEINS=("1VII" "1UBQ" "1LYZ" "1MBN" "2LZM" "1CRN" "1LYS")
declare -A LENGTHS=(["1VII"]=36 ["1UBQ"]=76 ["1LYZ"]=129 ["1MBN"]=153 ["2LZM"]=164 ["1CRN"]=199 ["1LYS"]=501)

echo "=== Ubuntu 22.04 Scaling Test (Simple) ==="
echo "Testing: ${PROTEINS[*]}"
echo "Output: $TEST_BASE"
echo ""

# Setup
mkdir -p "$TEST_BASE"/{output,logs}
echo "protein,length,preprocess_time,inference_time,total_time,status" > "$TEST_BASE/results.txt"

# Test each protein
for protein in "${PROTEINS[@]}"; do
    length=${LENGTHS[$protein]}
    echo "=== Testing $protein (${length}aa) ==="
    
    # Skip if already done
    if [ -f "$TEST_BASE/output/$protein/features.pkl" ] && [ -f "$TEST_BASE/output/$protein/ranked_0.pdb" ]; then
        echo "Already completed $protein, skipping..."
        continue
    fi
    
    mkdir -p "$TEST_BASE/output/$protein"
    
    # Preprocessing
    echo "Preprocessing $protein..."
    start_time=$(date +%s)
    
    if apptainer exec --nv \
        --bind "$SEQUENCE_DIR:/input:ro" \
        --bind "$TEST_BASE/output:/output" \
        --bind "$DB_DIR:/data:ro" \
        "$CONTAINER" \
        python /app/alphafold/run_alphafold_preprocess.py \
        --fasta_paths="/input/${protein}.fasta" \
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
        > "$TEST_BASE/logs/${protein}_preprocess.log" 2>&1; then
        
        preprocess_end=$(date +%s)
        preprocess_time=$((preprocess_end - start_time))
        echo "Preprocessing completed: ${preprocess_time}s"
        
        # Inference
        echo "Inference $protein..."
        inference_start=$(date +%s)
        
        if apptainer exec --nv \
            --bind "$TEST_BASE/output:/input" \
            --bind "$DB_DIR/params:/data/params:ro" \
            "$CONTAINER" \
            python /app/alphafold/run_alphafold_inference.py \
            --output_dir=/input \
            --data_dir=/data \
            --target_names="$protein" \
            --model_preset=monomer \
            --use_gpu_relax=false \
            > "$TEST_BASE/logs/${protein}_inference.log" 2>&1; then
            
            inference_end=$(date +%s)
            inference_time=$((inference_end - inference_start))
            total_time=$((preprocess_time + inference_time))
            
            echo "Inference completed: ${inference_time}s"
            echo "Total time: ${total_time}s"
            echo "$protein,$length,$preprocess_time,$inference_time,$total_time,SUCCESS" >> "$TEST_BASE/results.txt"
            echo "✓ $protein completed successfully"
        else
            echo "✗ Inference failed for $protein"
            echo "$protein,$length,$preprocess_time,FAILED,$preprocess_time,INFERENCE_FAILED" >> "$TEST_BASE/results.txt"
        fi
    else
        echo "✗ Preprocessing failed for $protein"
        echo "$protein,$length,FAILED,SKIPPED,0,PREPROCESS_FAILED" >> "$TEST_BASE/results.txt"
    fi
    
    echo ""
done

echo "=== Final Results ==="
echo "Results saved to: $TEST_BASE/results.txt"
cat "$TEST_BASE/results.txt"