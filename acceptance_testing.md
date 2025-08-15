# AlphaFold Apptainer Acceptance Testing Plan

## Overview

This plan validates the release of Apptainer definition files for AlphaFold by running comprehensive tests and documenting results.

## Test Environment

- **Containers:** `alphafold_ubuntu20.sif`, `alphafold_ubuntu22_cudnn896.sif`
- **AlphaFold Version:** 2.3.2
- **CUDA Version:** 12.2.2 (with CUDNN 8)
- **Databases:** UniRef90, MGnify, BFD/small_bfd, UniRef30, PDB70, PDB mmCIF
- **Hardware Requirements:**
  - GPU: NVIDIA A100/H100 (16GB+ VRAM)
  - CPU: 8-16 cores recommended
  - Memory: 64GB minimum, 128GB for large proteins
  - Storage: 100GB for test outputs

- **Container definitions:**
   - `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/docker/alphafold_ubuntu20.def`
   - `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/docker/alphafold_ubuntu22_cudnn896.def`

- **Test and data directory locations:** /scratch/alphafold/

## Test Matrix

| Test Type         | Sequence Lengths | Model Presets      | DB Presets      | Metrics Collected         |
|-------------------|------------------|--------------------|-----------------|--------------------------|
| Basic Functionality | 50, 150, 400     | monomer            | reduced_dbs     | Wall time, memory, GPU   |
| Performance Scaling | 100, 200, 400, 800, 1600 | monomer | reduced_dbs | Wall time, memory, GPU, MSA depth |
| Robustness         | 400, 3000        | monomer            | reduced_dbs     | Error handling, resume   |
| Resource Utilization | 100, 400, 800   | monomer            | reduced_dbs     | CPU/GPU utilization, I/O |

## Test Execution Steps

1. **Build Container**
   - `apptainer build alphafold_ubuntu20.sif alphafold_ubuntu20.def`
   - `apptainer build alphafold_ubuntu22_cudnn896.sif alphafold_ubuntu22_cudnn896.def`

2. **Run Basic Functionality Test**
   - Use provided Bash/Python scripts to run preprocessing and inference.
   - Collect logs and outputs.

3. **Run Performance Scaling Test**
   - Automate sequence generation and pipeline runs.
   - Parse metrics and compare to expected results.

4. **Run Robustness Test**
   - Simulate interruptions, missing/corrupt files, parallel runs.
   - Document error messages and recovery steps.

5. **Run Resource Utilization Test**
   - Monitor CPU, memory, GPU, and I/O during runs.
   - Save metrics for documentation.

## Metrics Collection

- Use `nvidia-smi dmon`, `sar`, `iostat` for system monitoring.
- Parse logs for wall time, memory, and error messages.

## Documentation

- Record all commands, outputs, and metrics.
- Compare actual results to expected tables.
- Note any deviations, errors, or required fixes.

## Model/Subagent Hints

- **Claude Code:** Use for script generation, log parsing, and markdown documentation.
- **GitHub Copilot:** Use for code completion and inline comments in scripts.
- **Subagents:**
  - `TestScriptGenerator`: Automates test script creation.
  - `MetricsParser`: Summarizes performance/resource metrics.
  - `DocFormatter`: Formats results into markdown/README.

---

## Reference: Test Plan Details

### Expected Results

| Sequence Length | Preprocessing Time | Inference Time | Total Time | GPU Memory |
|----------------|-------------------|----------------|------------|------------|
| 100 aa | 5-10 min | 2-3 min | 7-13 min | 6 GB |
| 200 aa | 10-20 min | 3-5 min | 13-25 min | 7 GB |
| 400 aa | 20-40 min | 5-10 min | 25-50 min | 9 GB |
| 800 aa | 40-80 min | 15-25 min | 55-105 min | 14 GB |
| 1600 aa | 80-160 min | 40-60 min | 120-220 min | 25 GB |

### Resource Requirements

- **CPU**: 8-16 cores recommended for preprocessing
- **Memory**: 32-64 GB for typical proteins, 128 GB for large proteins
- **GPU**: 16 GB for proteins <1000 aa, 32+ GB for larger
- **Storage**: 1-10 GB per protein for all outputs

---

## Test Execution Plan (Phases)

1. **Phase 1**: Basic functionality tests (1 hour)
   - Small sequences with reduced databases
   - Verify pipeline works end-to-end

2. **Phase 2**: Performance scaling tests (4 hours)
   - Run sequences of increasing length
   - Collect detailed metrics

3. **Phase 3**: Robustness tests (2 hours)
   - Interrupt/resume scenarios
   - Parallel execution
   - Error handling

4. **Phase 4**: Resource optimization (2 hours)
   - Find optimal thread counts
   - Test memory constraints
   - GPU sharing scenarios

Total estimated time: 9 hours for comprehensive testing

## Detailed Test Specifications

### Phase 1: Basic Functionality Tests

**Test Cases:**

1. **Small Protein Test (1UBQ - 76aa)**
   - Input: Ubiquitin sequence
   - Expected: Complete pipeline execution < 15 minutes
   - Validation: Check for all output files (PDB, pkl, timings.json)

2. **Medium Protein Test (1MBN - 153aa)**
   - Input: Myoglobin sequence  
   - Expected: Complete execution < 30 minutes
   - Validation: pLDDT score > 70, structure quality check

3. **Container Compatibility Test**
   - Run same sequence on both Ubuntu 20.04 and 22.04 containers
   - Compare outputs for consistency
   - Validate GPU utilization

**Test Script:** `test_basic_functionality.sh`

```bash
#!/bin/bash
# Basic functionality test
TEST_DIR="/scratch/acceptance_test_phase1"
mkdir -p $TEST_DIR/{sequences,outputs,logs}

# Test proteins
declare -A TEST_PROTEINS=(
    ["1UBQ"]="MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG"
    ["1MBN"]="MVLSEGEWQLVLHVWAKVEADVAGHGQDILIRLFKSHPETLEKFDRFKHLKTEAEMKASEDLKKHGVTVLTALGAILKKKGHHEAELKPLAQSHATKHKIPIKYLEFISEAIIHVLHSRHPGDFGADAQGAMNKALELFRKDIAAKYKELGYQG"
)

# Run tests and collect metrics
```

### Phase 2: Performance Scaling Tests

**Test Cases:**

1. **Sequence Length Scaling**
   - Lengths: 100, 200, 400, 800, 1600 amino acids
   - Measure: Wall time, GPU memory, MSA depth
   - Plot: Time vs sequence length curve

2. **Database Preset Comparison**
   - Same 400aa sequence with reduced_dbs vs full_dbs
   - Compare: Accuracy (pLDDT) vs speed tradeoff

3. **Model Preset Performance**
   - Test monomer vs monomer_ptm on 500aa sequence
   - Measure additional computational overhead

**Metrics Collection:**
- Preprocessing time (MSA generation)
- Inference time per model
- Peak GPU memory usage
- Total wall clock time
- Output quality metrics (pLDDT, pTM)

### Phase 3: Robustness Tests

**Test Cases:**

1. **Interrupt/Resume Test**
   - Start prediction for 1000aa protein
   - Kill process after MSA generation
   - Resume and verify completion

2. **Parallel Execution Test**
   - Run 4 predictions simultaneously
   - Monitor resource contention
   - Verify all complete successfully

3. **Error Handling Test**
   - Missing database files
   - Corrupted input FASTA
   - Out of memory scenarios
   - Invalid sequences (numbers, special chars)

4. **Long Running Test**
   - Very large protein (3000aa)
   - Monitor for memory leaks
   - Verify completion after extended run

### Phase 4: Resource Optimization Tests

**Test Cases:**

1. **CPU Thread Optimization**
   - Test with 4, 8, 16, 32 threads
   - Find optimal for MSA generation

2. **GPU Memory Management**
   - Test max sequence length per GPU memory tier
   - 16GB GPU: max length?
   - 40GB GPU: max length?
   - 80GB GPU: max length?

3. **Batch Processing Efficiency**
   - Sequential vs parallel preprocessing
   - GPU sharing between inference jobs

4. **I/O Performance**
   - Database on NFS vs local SSD
   - Output to different filesystems
   - Measure I/O wait times

## Test Data Generation

Use `generate_test_sequences.py` to create test sets:

```bash
# Generate standard test set
python generate_test_sequences.py --output-dir test_sequences

# Generate custom length sequence
python generate_test_sequences.py --custom-length 2000 --name huge_protein
```

## Automated Test Execution

### Master Test Runner

```bash
#!/bin/bash
# acceptance_test_runner.sh
# Runs all acceptance test phases and generates report

PHASES="basic scaling robustness optimization"
REPORT_DIR="acceptance_test_results_$(date +%Y%m%d)"

for phase in $PHASES; do
    echo "Running Phase: $phase"
    ./test_${phase}.sh > $REPORT_DIR/${phase}_output.log 2>&1
    parse_results.py --phase $phase --output $REPORT_DIR/${phase}_results.json
done

# Generate final report
generate_acceptance_report.py --results-dir $REPORT_DIR
```

## Metrics Collection Tools

### GPU Monitoring
```bash
nvidia-smi dmon -s mu -d 5 -o T > gpu_metrics.csv
```

### System Monitoring  
```bash
sar -r -u -d 5 > system_metrics.txt
iostat -x 5 > io_metrics.txt
```

### Custom Metrics Parser
```python
# parse_alphafold_metrics.py
import json
from pathlib import Path

def parse_timings(timings_file):
    """Extract key timing metrics from AlphaFold output."""
    with open(timings_file) as f:
        timings = json.load(f)
    
    return {
        'total_time': sum(timings.values()),
        'msa_time': timings.get('features', 0),
        'prediction_time': timings.get('predict_and_compile_model', 0),
        'relaxation_time': timings.get('relax', 0)
    }
```

## Results Documentation Template

### Test Summary Report

```markdown
# AlphaFold Acceptance Test Results

**Date:** [DATE]
**Tester:** [NAME]
**Environment:** [CLUSTER/NODE]

## Executive Summary
- All tests: [PASS/FAIL]
- Performance targets: [MET/NOT MET]
- Issues found: [COUNT]

## Detailed Results

### Phase 1: Basic Functionality
| Test Case | Container | Status | Time | Notes |
|-----------|-----------|--------|------|-------|
| 1UBQ (76aa) | Ubuntu 20.04 | PASS | 12m | |
| 1UBQ (76aa) | Ubuntu 22.04 | PASS | 13m | |

### Phase 2: Performance Scaling
[Performance graphs and tables]

### Phase 3: Robustness
[Error handling results]

### Phase 4: Resource Optimization  
[Optimization recommendations]

## Recommendations
1. Optimal configuration for production
2. Known limitations
3. Suggested improvements
```
