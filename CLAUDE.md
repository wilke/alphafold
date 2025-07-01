# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the official AlphaFold implementation by DeepMind for protein structure prediction. AlphaFold v2 was the breakthrough system that achieved near-experimental accuracy in CASP14, revolutionizing structural biology.

## Key Commands

### Installation and Setup

```bash
# Install AlphaFold package in development mode
pip install -e .

# Install Docker runner dependencies
pip3 install -r docker/requirements.txt

# Build Docker image
docker build -f docker/Dockerfile -t alphafold .

# Download all databases (2.62 TB uncompressed, 556 GB download)
scripts/download_all_data.sh <DOWNLOAD_DIR>

# Download reduced databases (faster, less accurate)
scripts/download_all_data.sh <DOWNLOAD_DIR> reduced_dbs
```

### Running AlphaFold Predictions

```bash
# Direct execution (requires all dependencies)
python run_alphafold.py \
  --fasta_paths=<path_to_fasta> \
  --max_template_date=2022-01-01 \
  --db_preset=<reduced_dbs|full_dbs> \
  --model_preset=<monomer|monomer_casp14|monomer_ptm|multimer> \
  --data_dir=<path_to_databases> \
  --output_dir=<output_path>

# Docker execution (recommended)
python3 docker/run_docker.py \
  --fasta_paths=<path_to_fasta> \
  --max_template_date=2022-01-01 \
  --db_preset=<reduced_dbs|full_dbs> \
  --model_preset=<monomer|monomer_casp14|monomer_ptm|multimer> \
  --data_dir=<path_to_databases> \
  --output_dir=<output_path>
```

### Testing

```bash
# Run all tests (requires matplotlib and mock)
python -m pytest

# Run specific test module
python -m pytest alphafold/model/

# Run specific test file  
python -m pytest run_alphafold_test.py

# Run tests with unittest
python -m unittest discover -s alphafold -p '*_test.py'
```

## Architecture Overview

### Main Entry Points

- `run_alphafold.py` - Main CLI for running predictions
- `docker/run_docker.py` - Docker wrapper (handles dependencies automatically)
- `notebooks/` - Contains Jupyter notebook interfaces

### Core Package Structure

```
alphafold/
├── common/          # Protein utilities and constants
│   ├── confidence.py     # pLDDT and confidence metrics
│   ├── protein.py        # Protein data structure
│   └── residue_constants.py  # Amino acid definitions
├── data/            # Data processing pipelines
│   ├── pipeline.py       # Monomer MSA/template pipeline
│   ├── pipeline_multimer.py  # Multimer pipeline
│   └── templates.py      # Template search and processing
├── model/           # Neural network architecture
│   ├── config.py         # Model configurations
│   ├── model.py          # Main model class
│   ├── modules.py        # Evoformer and structure modules  
│   └── folding.py        # Structure prediction logic
└── relax/           # Amber-based structure relaxation
    └── relax.py          # OpenMM relaxation pipeline
```

### Model Presets

- `monomer` - Single chain, fastest (default)
- `monomer_casp14` - 8x ensemble, matches CASP14 setup
- `monomer_ptm` - Includes predicted TM-score and PAE
- `multimer` - Multi-chain complex prediction

### Database Presets

- `reduced_dbs` - Uses small_bfd instead of full BFD (faster, less accurate)
- `full_dbs` - All databases including full BFD (default)

### Key Dependencies

- JAX - Neural network computation
- Haiku - Neural network layers  
- OpenMM - Structure relaxation
- BioPython - Sequence handling
- HH-suite, HMMER - MSA generation
- Kalign - Sequence alignment

## Development Guidelines

### When modifying AlphaFold code:

1. The codebase uses JAX/Haiku for neural networks - changes must be compatible with JAX transformations
2. Model configurations are in `alphafold/model/config.py` - modifications affect all predictions
3. Test files follow the pattern `*_test.py` and use absltest or unittest
4. The pipeline supports both CPU and GPU execution - ensure compatibility
5. Multimer models require additional databases (UniProt, PDB seqres)

### Output Structure

```
<output_dir>/<target_name>/
├── features.pkl              # Input features
├── ranked_*.pdb             # Final structures ordered by confidence  
├── unrelaxed_model_*.pdb    # Raw model outputs
├── relaxed_model_*.pdb      # After Amber relaxation
├── result_model_*.pkl       # Full model outputs including confidence metrics
├── ranking_debug.json       # pLDDT scores used for ranking
├── timings.json            # Runtime breakdown
└── msas/                   # MSA files from genetic search
```

### Key Metrics in Output

- `plddt` - Per-residue confidence (0-100, higher is better)
- `ptm` - Predicted TM-score (global fold confidence)
- `predicted_aligned_error` - Pairwise distance error predictions