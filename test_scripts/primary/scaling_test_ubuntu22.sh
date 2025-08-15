#!/bin/bash
# Comprehensive scaling test for Ubuntu 22.04 container
# Tests proteins from 36aa to 501aa to establish performance scaling curves

set -e

# Configuration
TEST_BASE="/scratch/alphafold_scaling_test_ubuntu22"
DB_DIR="/homes/wilke/databases"
CONTAINER="/scratch/alphafold/containers/alphafold_ubuntu22.sif"
SEQUENCE_DIR="/scratch/alphafold/scaling_test_sequences"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Test proteins in order of size
declare -a TEST_PROTEINS=("1VII" "1UBQ" "1LYZ" "1MBN" "2LZM" "1CRN" "1LYS")
declare -A PROTEIN_LENGTHS=(
    ["1VII"]=36
    ["1UBQ"]=76
    ["1LYZ"]=129
    ["1MBN"]=153
    ["2LZM"]=164
    ["1CRN"]=199
    ["1LYS"]=501
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m' 
YELLOW='\033[1;33m'
NC='\033[0m'

# Setup test environment
setup_scaling_test() {
    echo -e "${GREEN}=== Ubuntu 22.04 Scaling Test Setup ===${NC}"
    mkdir -p "$TEST_BASE"/{output,logs,metrics}
    cd "$TEST_BASE"
    
    # Create results file with headers
    echo "protein,length_aa,preprocess_time_s,preprocess_memory_kb,preprocess_cpu_time_s,inference_time_s,inference_memory_kb,total_time_s,features_size_bytes,pdb_count,status" > scaling_results.csv
    
    echo "Test directory: $TEST_BASE"
    echo "Testing ${#TEST_PROTEINS[@]} proteins: ${TEST_PROTEINS[*]}"
    echo ""
}

# Run single protein test
run_protein_test() {
    local protein=$1
    local length=${PROTEIN_LENGTHS[$protein]}
    local fasta_file="$SEQUENCE_DIR/${protein}.fasta"
    local output_dir="$TEST_BASE/output/$protein"
    local preprocess_log="$TEST_BASE/logs/${protein}_preprocess_${TIMESTAMP}.log"
    local inference_log="$TEST_BASE/logs/${protein}_inference_${TIMESTAMP}.log"
    
    echo -e "${YELLOW}=== Testing $protein (${length} aa) ===${NC}"
    
    # Check if FASTA exists
    if [ ! -f "$fasta_file" ]; then
        echo -e "${RED}FASTA file not found: $fasta_file${NC}"
        echo "$protein,$length,ERROR,0,0,ERROR,0,ERROR,0,0,FASTA_MISSING" >> scaling_results.csv
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    # Step 1: Preprocessing
    echo "Step 1/2: Preprocessing $protein..."
    local preprocess_start=$(date +%s)
    
    /usr/bin/time -v apptainer exec --nv \
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
        &> "$preprocess_log"
    
    local preprocess_exit=$?
    local preprocess_end=$(date +%s)
    local preprocess_time=$((preprocess_end - preprocess_start))
    
    # Extract preprocessing metrics
    local preprocess_memory=$(grep "Maximum resident set size" "$preprocess_log" | tail -1 | awk '{print $6}' || echo "0")
    local preprocess_cpu_time=$(grep "User time" "$preprocess_log" | tail -1 | awk '{print $4}' || echo "0")
    
    if [ $preprocess_exit -ne 0 ]; then
        echo -e "${RED}Preprocessing failed for $protein${NC}"
        echo "$protein,$length,FAILED,$preprocess_memory,$preprocess_cpu_time,SKIPPED,0,FAILED,0,0,PREPROCESS_FAILED" >> scaling_results.csv
        return 1
    fi
    
    # Check features file
    local features_file="$output_dir/features.pkl"
    local features_size=0
    if [ -f "$features_file" ]; then
        features_size=$(stat -c%s "$features_file")
        echo -e "${GREEN}Preprocessing completed: ${preprocess_time}s, features: $(echo $features_size | numfmt --to=iec)${NC}"
    else
        echo -e "${RED}Features file not created for $protein${NC}"
        echo "$protein,$length,$preprocess_time,$preprocess_memory,$preprocess_cpu_time,SKIPPED,0,$preprocess_time,0,0,NO_FEATURES" >> scaling_results.csv
        return 1
    fi
    
    # Step 2: Inference
    echo "Step 2/2: Inference $protein..."
    local inference_start=$(date +%s)
    
    /usr/bin/time -v apptainer exec --nv \
        --bind "$TEST_BASE/output:/input" \
        --bind "$DB_DIR/params:/data/params:ro" \
        "$CONTAINER" \
        python /app/alphafold/run_alphafold_inference.py \
        --output_dir=/input \
        --data_dir=/data \
        --target_names="$protein" \
        --model_preset=monomer \
        --use_gpu_relax=false \
        &> "$inference_log"
    
    local inference_exit=$?
    local inference_end=$(date +%s)
    local inference_time=$((inference_end - inference_start))
    
    # Extract inference metrics
    local inference_memory=$(grep "Maximum resident set size" "$inference_log" | tail -1 | awk '{print $6}' || echo "0")
    local pdb_count=$(ls -1 "$output_dir"/*.pdb 2>/dev/null | wc -l)
    
    local total_time=$((preprocess_time + inference_time))
    
    if [ $inference_exit -eq 0 ]; then
        echo -e "${GREEN}Inference completed: ${inference_time}s, PDB files: $pdb_count${NC}"
        echo -e "${GREEN}Total time for $protein: ${total_time}s (${preprocess_time}s + ${inference_time}s)${NC}"
        echo "$protein,$length,$preprocess_time,$preprocess_memory,$preprocess_cpu_time,$inference_time,$inference_memory,$total_time,$features_size,$pdb_count,SUCCESS" >> scaling_results.csv
    else
        echo -e "${RED}Inference failed for $protein${NC}"
        echo "$protein,$length,$preprocess_time,$preprocess_memory,$preprocess_cpu_time,FAILED,$inference_memory,$preprocess_time,$features_size,0,INFERENCE_FAILED" >> scaling_results.csv
        return 1
    fi
    
    echo ""
}

# Generate performance summary
generate_summary() {
    echo -e "${GREEN}=== Scaling Test Summary ===${NC}"
    echo ""
    echo "Results saved to: $TEST_BASE/scaling_results.csv"
    echo ""
    
    if [ -f "scaling_results.csv" ]; then
        echo "| Protein | Length (aa) | Preprocessing (min) | Inference (min) | Total (min) | Features (MB) | Status |"
        echo "|---------|-------------|---------------------|-----------------|-------------|---------------|--------|"
        
        tail -n +2 scaling_results.csv | while IFS=',' read -r protein length preprocess_time preprocess_memory preprocess_cpu_time inference_time inference_memory total_time features_size pdb_count status; do
            if [[ "$preprocess_time" =~ ^[0-9]+$ ]] && [[ "$inference_time" =~ ^[0-9]+$ ]]; then
                preprocess_min=$(echo "scale=1; $preprocess_time / 60" | bc -l)
                inference_min=$(echo "scale=1; $inference_time / 60" | bc -l) 
                total_min=$(echo "scale=1; $total_time / 60" | bc -l)
                features_mb=$(echo "scale=2; $features_size / 1048576" | bc -l)
                echo "| $protein | $length | $preprocess_min | $inference_min | $total_min | $features_mb | $status |"
            else
                echo "| $protein | $length | $preprocess_time | $inference_time | - | - | $status |"
            fi
        done
    fi
    
    echo ""
    echo "Detailed logs in: $TEST_BASE/logs/"
    echo "Raw data in: $TEST_BASE/scaling_results.csv"
}

# Main execution
main() {
    echo -e "${GREEN}=== AlphaFold Ubuntu 22.04 Scaling Test ===${NC}"
    echo "Container: $(basename $CONTAINER)"
    echo "Databases: $DB_DIR"
    echo "Test range: 36aa to 501aa (7 proteins)"
    echo ""
    
    setup_scaling_test
    
    # Test each protein
    local success_count=0
    local total_count=${#TEST_PROTEINS[@]}
    
    for protein in "${TEST_PROTEINS[@]}"; do
        if run_protein_test "$protein"; then
            ((success_count++))
        fi
    done
    
    generate_summary
    
    echo -e "${GREEN}Scaling test completed: $success_count/$total_count proteins successful${NC}"
    echo "Test completed at $(date)"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi