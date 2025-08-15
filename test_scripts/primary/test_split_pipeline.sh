#!/bin/bash
# Fixed comprehensive test script for AlphaFold split pipeline
# Fixes: Database path consistency, container bindings, proper error handling

set -e

# Configuration
TEST_BASE="/scratch/alphafold_split_pipeline_test"
ALPHAFOLD_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold"
DB_DIR="${DB_DIR:-/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases}"
CONTAINER_DIR="/scratch/alphafold/containers"
# Container configuration - supports single container or fallback list
CONTAINER="${ALPHAFOLD_CONTAINER:-$CONTAINER_DIR/alphafold_ubuntu22_cudnn896.sif}"
# Fallback container list if primary not found
FALLBACK_CONTAINERS=(
    "$CONTAINER_DIR/alphafold_ubuntu22.sif"
    "$CONTAINER_DIR/alphafold_ubuntu20.sif"
)
USE_CONTAINER="${USE_CONTAINER:-true}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESUME_MODE="${RESUME_MODE:-true}"

# Test proteins from PDB
declare -A TEST_PROTEINS=(
    ["1VII"]="MLSDEDFKAVFGMTRSAFANLPLWKQQNLKKEKGLF"  # 35 aa
    ["1UBQ"]="MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG"  # 76 aa
    ["1LYZ"]="KVFERCELARTLKRLGMDGYRGISLANWMCLAKWESGYNTRATNYNAGDRSTDYGIFQINSRYWCNDGKTPGAVNACHLSCSALLQDNIADAVACAKRVVRDPQGIRAWVAWRNRCQNRDVRQYVQGCGV"  # 129 aa
    ["1MBN"]="MVLSEGEWQLVLHVWAKVEADVAGHGQDILIRLFKSHPETLEKFDRFKHLKTEAEMKASEDLKKHGVTVLTALGAILKKKGHHEAELKPLAQSHATKHKIPIKYLEFISEAIIHVLHSRHPGDFGADAQGAMNKALELFRKDIAAKYKELGYQG"  # 153 aa
)

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verify prerequisites
check_prerequisites() {
    echo "=== Checking Prerequisites ==="
    
    # Check primary container and fallback list
    if [ -f "$CONTAINER" ]; then
        echo "✓ Primary container found: $(basename $CONTAINER)"
    else
        echo -e "${YELLOW}Warning: Primary container not found: $CONTAINER${NC}"
        echo "Checking fallback containers..."
        CONTAINER_FOUND=false
        for fallback in "${FALLBACK_CONTAINERS[@]}"; do
            if [ -f "$fallback" ]; then
                echo "✓ Using fallback container: $(basename $fallback)"
                CONTAINER="$fallback"
                CONTAINER_FOUND=true
                break
            fi
        done
        if [ "$CONTAINER_FOUND" = false ]; then
            echo -e "${RED}ERROR: No valid container found${NC}"
            echo "Checked:"
            echo "  - $CONTAINER"
            for fallback in "${FALLBACK_CONTAINERS[@]}"; do
                echo "  - $fallback"
            done
            exit 1
        fi
    fi
    
    # Check database directory
    if [ ! -d "$DB_DIR" ]; then
        echo -e "${RED}ERROR: Database directory not found: $DB_DIR${NC}"
        exit 1
    fi
    echo "✓ Database directory: $DB_DIR"
    
    # Check available databases
    echo "Available databases:"
    for db in bfd mgnify uniref90 uniref30 pdb70 pdb_mmcif params; do
        if [ -d "$DB_DIR/$db" ]; then
            size=$(du -sh "$DB_DIR/$db" 2>/dev/null | cut -f1)
            echo "  ✓ $db ($size)"
        else
            echo "  ✗ $db (missing)"
        fi
    done
    
    # Check disk space
    available=$(df /scratch | tail -1 | awk '{print $4}')
    echo "✓ Available space on /scratch: $((available/1024/1024))GB"
    
    echo ""
}

# Verify container has preprocessing script
verify_container_preprocessing() {
    local container=$1
    local container_name=$(basename "$container")
    
    echo "Checking preprocessing capability in $container_name..."
    
    if apptainer exec "$container" test -f /app/alphafold/run_alphafold_preprocess.py; then
        echo "✓ Preprocessing script found in $container_name"
    else
        echo -e "${RED}✗ Preprocessing script NOT found in $container_name${NC}"
        # Try to find it
        echo "Searching for preprocessing scripts..."
        apptainer exec "$container" find /app -name "*preprocess*" 2>/dev/null || true
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    echo "=== Setting up test environment ==="
    mkdir -p "$TEST_BASE"/{sequences,output,logs,metrics}
    cd "$TEST_BASE"
    
    # Create test FASTA files
    for pdb_id in "${!TEST_PROTEINS[@]}"; do
        cat > "sequences/${pdb_id}.fasta" << EOF
>${pdb_id}_test_protein
${TEST_PROTEINS[$pdb_id]}
EOF
        echo "Created sequence file: sequences/${pdb_id}.fasta (${#TEST_PROTEINS[$pdb_id]} aa)"
    done
    
    # Create result CSV headers
    echo "name,container,duration,memory,cpu_time,features_exist,exit_code,features_size" > "$TEST_BASE/preprocessing_results.csv"
    echo "name,container,duration,memory,gpu_memory,pdb_count,exit_code" > "$TEST_BASE/inference_results.csv"
    
    echo "Test directory: $TEST_BASE"
    echo ""
}

# Generate provenance file
generate_provenance() {
    echo "=== Generating Provenance File ==="
    local provenance_file="$TEST_BASE/test_provenance.json"
    
    # Get system information
    local hostname=$(hostname)
    local os_info=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
    local kernel_version=$(uname -r)
    local cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    local memory_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2 " " $3}')
    local gpu_info=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "No GPU detected")
    
    # Get container information
    local container_size=""
    if [ -f "$CONTAINER" ]; then
        container_size=$(du -h "$CONTAINER" | cut -f1)
    fi
    
    cat > "$provenance_file" << EOF
{
  "test_metadata": {
    "script_name": "test_split_pipeline.sh",
    "script_version": "fixed_version",
    "test_timestamp": "$TIMESTAMP",
    "test_id": "$(date +%Y%m%d_%H%M%S)_$(hostname)_$$",
    "execution_user": "$(whoami)",
    "working_directory": "$(pwd)"
  },
  "system_environment": {
    "hostname": "$hostname",
    "operating_system": "$os_info",
    "kernel_version": "$kernel_version",
    "cpu_model": "$cpu_info",
    "total_memory": "$memory_total",
    "gpu_model": "$gpu_info"
  },
  "alphafold_configuration": {
    "alphafold_directory": "$ALPHAFOLD_DIR",
    "database_directory": "$DB_DIR",
    "container_path": "$CONTAINER",
    "container_size": "$container_size",
    "use_container": "$USE_CONTAINER",
    "resume_mode": "$RESUME_MODE"
  },
  "test_parameters": {
    "test_base_directory": "$TEST_BASE",
    "proteins_tested": [$(for pdb_id in "${!TEST_PROTEINS[@]}"; do echo "\"$pdb_id\""; done | paste -sd,)],
    "protein_sequences": {$(for pdb_id in "${!TEST_PROTEINS[@]}"; do echo "\"$pdb_id\": \"${TEST_PROTEINS[$pdb_id]}\""; done | paste -sd,)}
  },
  "git_information": {
    "repository_url": "$(cd $ALPHAFOLD_DIR && git remote get-url origin 2>/dev/null || echo 'Unknown')",
    "current_branch": "$(cd $ALPHAFOLD_DIR && git branch --show-current 2>/dev/null || echo 'Unknown')",
    "current_commit": "$(cd $ALPHAFOLD_DIR && git rev-parse HEAD 2>/dev/null || echo 'Unknown')",
    "commit_date": "$(cd $ALPHAFOLD_DIR && git log -1 --format=%cd 2>/dev/null || echo 'Unknown')",
    "repository_status": "$(cd $ALPHAFOLD_DIR && git status --porcelain 2>/dev/null | wc -l || echo 'Unknown') files modified"
  },
  "command_line": {
    "script_path": "$0",
    "arguments": "$@",
    "environment_variables": {
      "DB_DIR": "$DB_DIR",
      "ALPHAFOLD_CONTAINER": "${ALPHAFOLD_CONTAINER:-not_set}",
      "USE_CONTAINER": "$USE_CONTAINER",
      "RESUME_MODE": "$RESUME_MODE"
    }
  }
}
EOF

    echo "Provenance file created: $provenance_file"
    echo ""
}

# Monitor system resources
start_monitoring() {
    local name=$1
    local log_dir="$TEST_BASE/metrics/$name"
    mkdir -p "$log_dir"
    
    # GPU monitoring
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi dmon -s mu -d 5 -o T > "$log_dir/gpu_metrics.csv" 2>&1 &
        echo $! > "$log_dir/gpu_monitor.pid"
    fi
    
    # System monitoring with sar
    if command -v sar &> /dev/null; then
        sar -r -u 5 > "$log_dir/system_metrics.txt" 2>&1 &
        echo $! > "$log_dir/sar_monitor.pid"
    fi
}

# Stop monitoring
stop_monitoring() {
    local name=$1
    local log_dir="$TEST_BASE/metrics/$name"
    
    for pid_file in "$log_dir"/*.pid; do
        if [ -f "$pid_file" ]; then
            kill $(cat "$pid_file") 2>/dev/null || true
            rm "$pid_file"
        fi
    done
}

# Build database path arguments - FIXED VERSION
build_database_args() {
    # Check which databases are available and build appropriate paths
    local args=""
    
    # Required databases with fallbacks
    if [ -d "$DB_DIR/uniref90" ]; then
        args="$args --uniref90_database_path=/data/uniref90/uniref90.fasta"
    fi
    
    if [ -d "$DB_DIR/mgnify" ]; then
        args="$args --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa"
    fi
    
    if [ -d "$DB_DIR/bfd" ]; then
        args="$args --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt"
    elif [ -d "$DB_DIR/small_bfd" ]; then
        args="$args --small_bfd_database_path=/data/small_bfd/bfd-first_non_consensus_sequences.fasta"
    fi
    
    if [ -d "$DB_DIR/uniref30" ]; then
        args="$args --uniref30_database_path=/data/uniref30/UniRef30_2021_03"
    fi
    
    if [ -d "$DB_DIR/pdb70" ]; then
        args="$args --pdb70_database_path=/data/pdb70/pdb70"
    fi
    
    if [ -d "$DB_DIR/pdb_mmcif" ]; then
        args="$args --template_mmcif_dir=/data/pdb_mmcif/mmcif_files"
        args="$args --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat"
    fi
    
    echo "$args"
}

# Run preprocessing - FIXED VERSION
run_preprocessing() {
    local fasta=$1
    local container=$2
    local name=$(basename "$fasta" .fasta)
    local container_name=$(basename "$container" .sif)
    local output_dir="$TEST_BASE/output"
    local log_file="$TEST_BASE/logs/${name}_${container_name}_preprocess_${TIMESTAMP}.log"
    local features_file="$output_dir/$name/features.pkl"
    
    # Check if features already exist and resume mode is enabled
    if [ "$RESUME_MODE" = "true" ] && [ -f "$features_file" ]; then
        echo -e "${GREEN}[$(date)] Features already exist for $name ($container_name), skipping preprocessing${NC}"
        local features_size=$(stat -c%s "$features_file" 2>/dev/null || echo "0")
        echo "$name,$container_name,SKIPPED,0,0,true,0,${features_size}" >> "$TEST_BASE/preprocessing_results.csv"
        return 0
    fi
    
    echo -e "${YELLOW}[$(date)] Starting preprocessing for $name using $container_name${NC}"
    start_monitoring "${name}_${container_name}_preprocess"
    
    local start_time=$(date +%s)
    
    # Build database arguments
    local db_args=$(build_database_args)
    
    # FIXED: Container execution with proper path consistency
    /usr/bin/time -v apptainer exec --nv \
        --bind "$TEST_BASE/sequences:/input:ro" \
        --bind "$output_dir:/output" \
        --bind "$DB_DIR:/data:ro" \
        "$container" \
        python /app/alphafold/run_alphafold_preprocess.py \
        --fasta_paths="/input/$(basename $fasta)" \
        --output_dir=/output \
        --data_dir=/data \
        $db_args \
        --db_preset=full_dbs \
        --model_preset=monomer \
        --max_template_date=2022-01-01 \
        &> "$log_file"
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    stop_monitoring "${name}_${container_name}_preprocess"
    
    # Extract metrics from log
    local max_memory=$(grep "Maximum resident set size" "$log_file" | tail -1 | awk '{print $6}' || echo "0")
    local cpu_time=$(grep "User time" "$log_file" | tail -1 | awk '{print $4}' || echo "0")
    
    # Check if features.pkl was created
    local features_exist="false"
    local features_size="0"
    if [ -f "$output_dir/$name/features.pkl" ]; then
        features_exist="true"
        features_size=$(stat -c%s "$output_dir/$name/features.pkl" 2>/dev/null || echo "0")
    fi
    
    # Log results
    echo "$name,$container_name,$duration,$max_memory,$cpu_time,$features_exist,$exit_code,$features_size" >> "$TEST_BASE/preprocessing_results.csv"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[$(date)] Preprocessing completed for $name ($container_name) in ${duration}s${NC}"
        echo "Features size: $(echo $features_size | numfmt --to=iec)"
    else
        echo -e "${RED}[$(date)] Preprocessing failed for $name ($container_name) (exit code: $exit_code)${NC}"
        echo "Check log: $log_file"
    fi
    
    return $exit_code
}

# Run inference - FIXED VERSION
run_inference() {
    local name=$1
    local container=$2
    local container_name=$(basename "$container" .sif)
    local output_dir="$TEST_BASE/output"
    local log_file="$TEST_BASE/logs/${name}_${container_name}_inference_${TIMESTAMP}.log"
    local features_file="$output_dir/$name/features.pkl"
    
    # Check if features exist
    if [ ! -f "$features_file" ]; then
        echo -e "${RED}[$(date)] Features not found for $name, skipping inference${NC}"
        echo "$name,$container_name,SKIPPED,0,0,0,1" >> "$TEST_BASE/inference_results.csv"
        return 1
    fi
    
    echo -e "${YELLOW}[$(date)] Starting inference for $name using $container_name${NC}"
    start_monitoring "${name}_${container_name}_inference"
    
    local start_time=$(date +%s)
    
    # FIXED: Inference with proper path consistency
    /usr/bin/time -v apptainer exec --nv \
        --bind "$output_dir:/input" \
        --bind "$DB_DIR/params:/data/params:ro" \
        "$container" \
        python /app/alphafold/run_alphafold_inference.py \
        --output_dir=/input \
        --data_dir=/data \
        --target_names="$name" \
        --model_preset=monomer \
        --use_gpu_relax=false \
        &> "$log_file"
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    stop_monitoring "${name}_${container_name}_inference"
    
    # Extract metrics from log
    local max_memory=$(grep "Maximum resident set size" "$log_file" | tail -1 | awk '{print $6}' || echo "0")
    
    # Count PDB files created
    local pdb_count=$(ls -1 "$output_dir/$name"/*.pdb 2>/dev/null | wc -l)
    
    # Log results
    echo "$name,$container_name,$duration,$max_memory,0,$pdb_count,$exit_code" >> "$TEST_BASE/inference_results.csv"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[$(date)] Inference completed for $name ($container_name) in ${duration}s${NC}"
        echo "PDB files created: $pdb_count"
    else
        echo -e "${RED}[$(date)] Inference failed for $name ($container_name) (exit code: $exit_code)${NC}"
        echo "Check log: $log_file"
    fi
    
    return $exit_code
}

# Run complete pipeline test for one protein
run_pipeline_test() {
    local fasta=$1
    local name=$(basename "$fasta" .fasta)
    
    echo -e "${YELLOW}=== Testing $name (${#TEST_PROTEINS[$name]} amino acids) ===${NC}"
    
    # Test with selected container
    local container_name=$(basename "$CONTAINER" .sif)
    echo -e "${YELLOW}--- Using $container_name ---${NC}"
    
    # Verify container has preprocessing capability
    if ! verify_container_preprocessing "$CONTAINER"; then
        echo -e "${RED}Error: $container_name - no preprocessing capability${NC}"
        return 1
    fi
    
    # Run preprocessing
    echo "Step 1/2: Preprocessing..."
    if run_preprocessing "$fasta" "$CONTAINER"; then
        echo "Step 2/2: Inference..."
        run_inference "$name" "$CONTAINER"
    else
        echo -e "${RED}Preprocessing failed for $container_name${NC}"
        return 1
    fi
    
    echo ""
}

# Generate summary report
generate_summary() {
    echo -e "${YELLOW}=== Test Summary ===${NC}"
    
    if [ -f "$TEST_BASE/preprocessing_results.csv" ]; then
        echo "Preprocessing Results:"
        column -t -s ',' "$TEST_BASE/preprocessing_results.csv" | head -10
        echo ""
    fi
    
    if [ -f "$TEST_BASE/inference_results.csv" ]; then
        echo "Inference Results:"
        column -t -s ',' "$TEST_BASE/inference_results.csv" | head -10
        echo ""
    fi
    
    echo "Detailed logs in: $TEST_BASE/logs/"
    echo "Metrics in: $TEST_BASE/metrics/"
    echo "Outputs in: $TEST_BASE/output/"
}

# Main execution
main() {
    echo -e "${GREEN}=== AlphaFold Split Pipeline Test (Fixed Version) ===${NC}"
    echo "Testing container: $(basename $CONTAINER)"
    echo "Database directory: $DB_DIR"
    echo "Test directory: $TEST_BASE"
    echo ""
    
    check_prerequisites
    setup_test_env
    generate_provenance
    
    # Test with single protein first (1VII - smallest)
    if [ "${1:-}" = "quick" ]; then
        echo "Running quick test with 1VII only..."
        run_pipeline_test "$TEST_BASE/sequences/1VII.fasta"
    else
        echo "Running full test with all proteins..."
        # Run tests for all proteins
        for pdb_id in "${!TEST_PROTEINS[@]}"; do
            run_pipeline_test "$TEST_BASE/sequences/$pdb_id.fasta"
        done
    fi
    
    generate_summary
    
    echo -e "${GREEN}Test completed at $(date)${NC}"
}

# Allow sourcing for individual function testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi