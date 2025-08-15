#!/bin/bash
# AlphaFold Basic Functionality Test
# Tests both Ubuntu 20.04 and Ubuntu 22.04 (with CUDNN 8.9.6 fix) containers

set -e

# Configuration
TEST_BASE="/scratch/alphafold"
CONTAINERS_DIR="$TEST_BASE/containers"
SEQUENCES_DIR="$TEST_BASE/test_sequences"
OUTPUTS_DIR="$TEST_BASE/test_outputs"
LOGS_DIR="$TEST_BASE/test_logs"

# Use NFS databases for now (copying takes too long)
DB_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases"

# Containers to test
UBUNTU20_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu20.sif"
UBUNTU22_CONTAINER="$CONTAINERS_DIR/alphafold_ubuntu22.sif"

# Test proteins (small for basic functionality)
TEST_PROTEINS=("1UBQ" "1MBN")

echo "=== AlphaFold Basic Functionality Test ==="
echo "Date: $(date)"
echo "Test Base: $TEST_BASE"
echo "Containers: Ubuntu 20.04, Ubuntu 22.04 (CUDNN 8.9.6)"
echo "Database: $DB_DIR"
echo

# Check prerequisites
echo "Checking prerequisites..."
for container in "$UBUNTU20_CONTAINER" "$UBUNTU22_CONTAINER"; do
    if [ ! -f "$container" ]; then
        echo "✗ Container not found: $container"
        exit 1
    fi
    echo "✓ Found: $(basename $container)"
done

if [ ! -d "$DB_DIR/params" ]; then
    echo "✗ Database parameters not found: $DB_DIR/params"
    exit 1
fi
echo "✓ Database parameters found"
echo

# Create output directories
for protein in "${TEST_PROTEINS[@]}"; do
    mkdir -p "$OUTPUTS_DIR/ubuntu20/$protein"
    mkdir -p "$OUTPUTS_DIR/ubuntu22/$protein"
    mkdir -p "$LOGS_DIR"
done

# Function to run AlphaFold test
run_test() {
    local container=$1
    local protein=$2
    local output_subdir=$3
    local container_name=$4
    
    echo "Running $protein on $container_name..."
    
    local fasta_file="$SEQUENCES_DIR/$protein.fasta"
    local output_dir="$OUTPUTS_DIR/$output_subdir/$protein"
    local log_file="$LOGS_DIR/${protein}_${output_subdir}.log"
    
    if [ ! -f "$fasta_file" ]; then
        echo "✗ FASTA file not found: $fasta_file"
        return 1
    fi
    
    # Run AlphaFold with timing
    local start_time=$(date +%s)
    
    timeout 1800 /usr/bin/time -v apptainer run --nv \
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
        > "$log_file" 2>&1
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ $protein on $container_name: SUCCESS (${duration}s)"
        
        # Check outputs
        local ranked_pdb="$output_dir/$protein/ranked_0.pdb"
        local timings_json="$output_dir/$protein/timings.json"
        
        if [ -f "$ranked_pdb" ] && [ -f "$timings_json" ]; then
            local pdb_size=$(wc -c < "$ranked_pdb")
            echo "  - Output PDB: ${pdb_size} bytes"
            echo "  - Timings: $(grep 'predict_and_compile_model' "$timings_json" || echo 'N/A')"
        else
            echo "  ⚠ Missing expected outputs"
        fi
    elif [ $exit_code -eq 124 ]; then
        echo "✗ $protein on $container_name: TIMEOUT (${duration}s)"
    else
        echo "✗ $protein on $container_name: FAILED (exit code: $exit_code, ${duration}s)"
        echo "  Log: $log_file"
    fi
    
    return $exit_code
}

# Test matrix
echo "Starting test matrix..."
echo

# Results tracking
declare -A results
total_tests=0
passed_tests=0

# Run tests
for protein in "${TEST_PROTEINS[@]}"; do
    echo "=== Testing $protein ==="
    
    # Test Ubuntu 20.04
    ((total_tests++))
    if run_test "$UBUNTU20_CONTAINER" "$protein" "ubuntu20" "Ubuntu 20.04"; then
        ((passed_tests++))
        results["${protein}_ubuntu20"]="PASS"
    else
        results["${protein}_ubuntu20"]="FAIL"
    fi
    
    # Test Ubuntu 22.04
    ((total_tests++))
    if run_test "$UBUNTU22_CONTAINER" "$protein" "ubuntu22" "Ubuntu 22.04"; then
        ((passed_tests++))
        results["${protein}_ubuntu22"]="PASS"
    else
        results["${protein}_ubuntu22"]="FAIL"
    fi
    
    echo
done

# Summary
echo "=== Test Summary ==="
echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $((total_tests - passed_tests))"
echo "Success rate: $(( passed_tests * 100 / total_tests ))%"
echo

echo "Detailed results:"
for key in "${!results[@]}"; do
    echo "  $key: ${results[$key]}"
done

# Generate results file
results_file="$LOGS_DIR/basic_functionality_results.json"
cat > "$results_file" << EOF
{
  "test_date": "$(date -Iseconds)",
  "test_type": "basic_functionality",
  "containers_tested": [
    "ubuntu20 (CUDNN 8.9.6)",
    "ubuntu22 (CUDNN 8.9.6 - fixed)"
  ],
  "total_tests": $total_tests,
  "passed_tests": $passed_tests,
  "success_rate": $(( passed_tests * 100 / total_tests )),
  "results": {
EOF

first=true
for key in "${!results[@]}"; do
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$results_file"
    fi
    echo "    \"$key\": \"${results[$key]}\"" >> "$results_file"
done

cat >> "$results_file" << EOF
  }
}
EOF

echo
echo "✓ Results saved to: $results_file"
echo "✓ Logs saved to: $LOGS_DIR"
echo "✓ Outputs saved to: $OUTPUTS_DIR"

# Exit with failure if any tests failed
if [ $passed_tests -eq $total_tests ]; then
    echo
    echo "🎉 All tests passed! Both Ubuntu versions working correctly."
    exit 0
else
    echo
    echo "❌ Some tests failed. Check logs for details."
    exit 1
fi