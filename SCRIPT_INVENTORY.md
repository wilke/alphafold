# Complete Script and Data Inventory - AlphaFold Ubuntu 22.04 Analysis

**Inventory Date**: August 15, 2025  
**Analysis Period**: August 7-15, 2025  

---

## Scripts Developed During Analysis

### Primary Test Scripts (/scratch/alphafold/)

| Script Name | Size | Purpose | Key Features |
|-------------|------|---------|--------------|
| `test_split_pipeline_fixed.sh` | 13.7KB | Comprehensive split pipeline testing | Multi-container, resume mode, metrics collection |
| `scaling_test_ubuntu22.sh` | 8.3KB | Ubuntu 22.04 full scaling analysis | 7 proteins, detailed timing, error handling |
| `scaling_test_simple.sh` | 4.0KB | Simplified robust scaling test | Clean CSV output, error recovery |
| `test_199aa_single.sh` | 3.1KB | 199aa protein validation | Issue resolution, target naming fix |
| `validate_readiness.sh` | 2.9KB | Pre-test validation framework | Container and database verification |

### Utility and Debugging Scripts (/scratch/alphafold/)

| Script Name | Size | Purpose | Features |
|-------------|------|---------|----------|
| `generate_scaling_sequences.py` | 3.3KB | Test protein sequence generation | 7 proteins (36aa-501aa), FASTA validation |
| `debug_inference.sh` | 1.6KB | Ubuntu 20.04 inference debugging | Individual protein testing, timing |
| `debug_inference_ubuntu22.sh` | 1.5KB | Ubuntu 22.04 inference debugging | Container-specific validation |
| `test_containers_simple.sh` | 3.6KB | Basic container functionality test | CUDNN, JAX, imports validation |
| `test_basic_functionality.sh` | 5.7KB | Basic pipeline functionality | Legacy testing framework |

### Legacy/Development Scripts (/scratch/alphafold/)

| Script Name | Size | Purpose | Status |
|-------------|------|---------|--------|
| `quick_container_validation.sh` | 2.7KB | Initial container testing | Superseded by validate_readiness.sh |
| `test_performance_simple.sh` | 6.7KB | Early performance testing | Superseded by scaling tests |
| `test_single_protein.sh` | 3.5KB | Single protein testing | Integrated into scaling framework |

---

## Test Data and Sequences

### Primary Test Sequences (/scratch/alphafold/scaling_test_sequences/)

| File | Size | Protein | Length | Purpose |
|------|------|---------|--------|---------|
| `1VII.fasta` | 68B | Villin headpiece | 36aa | Small protein baseline |
| `1UBQ.fasta` | 101B | Ubiquitin | 76aa | Small-medium protein |
| `1LYZ.fasta` | 154B | Lysozyme | 129aa | Medium protein |
| `1MBN.fasta` | 180B | Myoglobin | 153aa | Medium protein |
| `2LZM.fasta` | 164B | T4 Lysozyme | 164aa | Medium-large protein |
| `1CRN.fasta` | 218B | Crambin variant | 199aa | Large protein (original, has dash) |
| `1LYS.fasta` | 593B | Large lysozyme | 501aa | Very large protein |

### Corrected Test Sequences (/scratch/alphafold/)

| File | Size | Purpose | Issue Resolved |
|------|------|---------|----------------|
| `test_199aa_fixed.fasta` | 233B | Corrected 199aa protein | Removed illegal dash character |
| `1CRN_fixed.fasta` | 219B | Fixed crambin sequence | Removed dash, preserved length |
| `test_199aa.fasta` | 221B | Intermediate 199aa test | Length validation attempt |

---

## Test Results Data Directories

### Primary Results (/scratch/alphafold/)

| Directory | Size | Purpose | Contents |
|-----------|------|---------|----------|
| `scaling_test_ubuntu22_simple/` | - | Complete scaling test results | 7 proteins, logs, CSV results |
| `test_199aa_results/` | - | 199aa validation data | Features, PDB files, timing data |
| `test_outputs/` | - | General test outputs | Legacy test results |
| `test_logs/` | - | Test execution logs | Debugging and monitoring data |
| `performance_test/` | - | Performance analysis data | Early performance testing |
| `test_sequences/` | - | Legacy test sequences | Early sequence development |

### Key Result Files

| File/Directory | Location | Purpose |
|----------------|----------|---------|
| `scaling_results.csv` | `scaling_test_ubuntu22_simple/` | Complete performance matrix |
| `features.pkl` | `test_199aa_results/output/test_199aa_fixed/` | 199aa preprocessed features (11MB) |
| `*.pdb` files | Various result directories | Protein structure outputs |
| Timing logs | `*/logs/` subdirectories | Detailed performance measurements |

---

## Analysis Reports and Documentation

### Primary Reports (/scratch/alphafold/)

| Report | Size | Purpose | Status |
|--------|------|---------|--------|
| `AlphaFold_Ubuntu22_Comprehensive_Analysis_Report.md` | 20.5KB | Unified final analysis | Complete |
| `Ubuntu22_Scaling_Test_Report.md` | 13.7KB | Primary scaling analysis | Complete |
| `performance_comparison_comprehensive.md` | 5.7KB | Historical comparison | Complete |
| `ubuntu22_performance_analysis.md` | 3.1KB | Performance planning | Complete |
| `performance_comparison.md` | 1.9KB | Container validation | Complete |
| `final_acceptance_report.md` | 6.3KB | Legacy acceptance testing | Archive |

### Work Reports (/scratch/alphafold/reports/)

| Report | Size | Purpose |
|--------|------|---------|
| `work-250815.alphafold-ubuntu22-comprehensive.md` | 23.8KB | Complete research documentation |
| `work-250815.alphafold-ubuntu22-analysis.md` | 8.5KB | Original work summary |

---

## Container Assets

### Production Containers (/scratch/alphafold/containers/)

| Container | Size | Purpose | Status |
|-----------|------|---------|--------|
| `alphafold_ubuntu20.sif` | 23GB | Baseline Ubuntu 20.04 | Production validated |
| `alphafold_ubuntu22.sif` | 8.6GB | Ubuntu 22.04 with CUDNN fix | Production validated |

---

## Historical Context Scripts (Main Project) - **UPDATED August 15, 2025**

### Existing Scripts (/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/)

| Script | Purpose | Status | Relationship to Current Work |
|--------|---------|--------|------------------------------|
| `test_split_pipeline.sh` | Original split pipeline testing | **ACTIVE** | Foundation for `test_split_pipeline_fixed.sh` |
| ~~`test_basic_functionality.sh`~~ | Basic functionality testing | **DELETED** | Evolved into current test framework |
| `test_performance_scaling.sh` | Performance scaling analysis | **ACTIVE** | Superseded by scaling_test_ubuntu22.sh |
| ~~`launch_acceptance_tests.sh`~~ | Acceptance test coordination | **DELETED** | Related to overall testing strategy |
| `generate_test_sequences.py` | Test sequence generation | **ACTIVE** | Predecessor to scaling sequence generation |

### Additional Deleted Scripts - **August 15, 2025**

| Script | Purpose | Status | Reason for Deletion |
|--------|---------|--------|-------------------|
| ~~`test_direct_preprocess.sh`~~ | Simple preprocessing test | **DELETED** | Superseded by comprehensive testing framework |
| ~~`run_inference_1VII.sh`~~ | Basic inference test | **DELETED** | Functionality absorbed into scaling framework |
| ~~`monitor_full_test.sh`~~ | Basic monitoring script | **DELETED** | Redundant functionality |

---

## ✅ COMPLETED ORGANIZATION: Dedicated Test Scripts Directory

**Created**: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/test_scripts/` - **IMPLEMENTED August 15, 2025**

**Final Organization**:
```
/nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/test_scripts/
├── primary/                    # Main testing frameworks ✅ COMPLETE
│   ├── test_split_pipeline_fixed.sh
│   ├── scaling_test_ubuntu22.sh  
│   ├── scaling_test_simple.sh
│   └── validate_readiness.sh
├── utilities/                  # Helper and debugging scripts ✅ COMPLETE
│   ├── generate_scaling_sequences.py
│   ├── debug_inference.sh
│   ├── debug_inference_ubuntu22.sh
│   └── test_containers_simple.sh
├── validation/                 # Specific issue resolution ✅ COMPLETE
│   └── test_199aa_single.sh
└── legacy/                     # Archive older scripts ✅ COMPLETE
    ├── test_basic_functionality.sh
    ├── test_single_protein.sh
    └── quick_container_validation.sh
```

---

## ✅ COMPLETED ACTIONS - August 15, 2025

### 1. ✅ Created Organized Script Directory
```bash
mkdir -p /nfs/ml_lab/projects/ml_lab/cepi/alphafold/alphafold/test_scripts/{primary,utilities,validation,legacy}
```

### 2. ✅ Moved Scripts by Category
- **Primary**: Core testing frameworks used for final analysis (4 scripts)
- **Utilities**: Helper scripts and tools (4 scripts) 
- **Validation**: Issue-specific resolution scripts (1 script)
- **Legacy**: Superseded but preserved scripts (3 scripts)

### 3. ✅ Updated Documentation
- ✅ Added script directory structure to comprehensive report
- ✅ Updated complete file inventory with new locations
- ✅ Documented script relationships and evolution

### 4. ✅ Preserved Historical Context
- ✅ Maintained original timestamps and permissions
- ✅ Documented script evolution and relationships  
- ✅ Preserved provenance for research reproducibility

---

## Script Dependencies and Relationships

### Test Framework Evolution
```
Original → Enhanced → Final
test_split_pipeline.sh → test_split_pipeline_fixed.sh → Production Ready
test_basic_functionality.sh → scaling_test_ubuntu22.sh → Comprehensive Analysis
```

### Utility Chain
```
generate_test_sequences.py → generate_scaling_sequences.py → Complete Test Set
debug_inference.sh → Container-specific versions → Validation Framework
```

### Data Flow
```
Sequences → Scripts → Results → Reports → Production Recommendations
FASTA files → Test scripts → CSV/Logs → Markdown reports → Deployment guidance
```

This organization provides **clear structure**, **preserved provenance**, and **easy navigation** for both current use and future research reproducibility.