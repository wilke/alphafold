# AlphaFold Test Scripts

This directory contains test scripts and utilities for validating AlphaFold installations and containers.

## Available Tests

### 1. `test_alphafold_simple.sh`
Simple test script for basic AlphaFold functionality validation.

### 2. `test_jax_minimal.py` 
Python script to test JAX installation and GPU detection.

### 3. `jax_minimal_test.def`
Minimal Apptainer definition for testing JAX/CUDA compatibility.

## Running Tests

### Container Validation
```bash
# Test dependencies in container
apptainer exec --nv alphafold.sif python tests/test_jax_minimal.py

# Run simple AlphaFold test
bash tests/test_alphafold_simple.sh
```

### GPU Detection Test
```bash
python tests/test_jax_minimal.py
```

Expected output:
```
JAX version: 0.4.26
Devices: [cuda(id=0), cuda(id=1), ...]
GPU detected: True
```

## Test Framework

For comprehensive testing, see the test orchestration scripts in `/scratch/`:
- `run_alphafold_test.sh` - Single test runner
- `run_all_alphafold_tests.sh` - Full test matrix execution

These scripts provide parameterized testing with timing metrics and detailed logging.