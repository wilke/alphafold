# AlphaFold Split Pipeline

This implementation splits AlphaFold into two independent scripts for better performance and resource utilization.

## Overview

- **`run_alphafold_preprocess.py`** - Handles MSA generation, template search, and feature generation (CPU-intensive)
- **`run_alphafold_inference.py`** - Runs neural network inference and structure relaxation (GPU-intensive)

## Benefits

1. **Resource Optimization**: Run preprocessing on CPU nodes and inference on GPU nodes
2. **Parallel Processing**: Preprocess multiple sequences in parallel
3. **Fault Tolerance**: Resume from saved features if inference fails
4. **Batch Processing**: Accumulate preprocessed features, then batch process on GPU
5. **Caching**: Reuse features for different model presets

## Usage

### Step 1: Preprocessing

```bash
python run_alphafold_preprocess.py \
  --fasta_paths=target.fasta \
  --output_dir=/path/to/output \
  --data_dir=/path/to/alphafold/data \
  --uniref90_database_path=/path/to/uniref90/uniref90.fasta \
  --mgnify_database_path=/path/to/mgnify/mgy_clusters_2022_05.fa \
  --template_mmcif_dir=/path/to/pdb_mmcif/mmcif_files \
  --max_template_date=2022-01-01 \
  --obsolete_pdbs_path=/path/to/pdb_mmcif/obsolete.dat \
  --db_preset=full_dbs \
  --model_preset=monomer \
  --bfd_database_path=/path/to/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
  --uniref30_database_path=/path/to/uniref30/UniRef30_2021_03 \
  --pdb70_database_path=/path/to/pdb70/pdb70
```

Additional preprocessing options:
- `--use_precomputed_msas`: Skip MSA generation if MSA files exist
- `--skip_existing`: Skip targets that already have features.pkl

### Step 2: Inference

```bash
python run_alphafold_inference.py \
  --output_dir=/path/to/output \
  --data_dir=/path/to/alphafold/data \
  --model_preset=monomer \
  --use_gpu_relax=true
```

Additional inference options:
- `--target_names`: Specify which targets to run (default: all with features.pkl)
- `--benchmark`: Run inference twice to measure time without compilation
- `--models_to_relax`: Choose which models to relax (all/best/none)

## Output Structure

```
output_dir/
├── target_name/
│   ├── features.pkl              # Preprocessed features (from step 1)
│   ├── preprocessing_metadata.json # Preprocessing info
│   ├── msas/                     # MSA files
│   │   ├── uniref90_hits.sto
│   │   ├── mgnify_hits.sto
│   │   └── bfd_uniref_hits.a3m
│   ├── ranked_*.pdb             # Final structures (from step 2)
│   ├── unrelaxed_model_*.pdb
│   ├── relaxed_model_*.pdb
│   ├── result_model_*.pkl
│   ├── confidence_*.json
│   ├── pae_*.json
│   ├── ranking_debug.json
│   └── timings.json
```

## Example: Batch Processing

```bash
# Preprocess multiple sequences in parallel
for fasta in *.fasta; do
  python run_alphafold_preprocess.py \
    --fasta_paths=$fasta \
    --output_dir=/path/to/output \
    ... &
done
wait

# Run inference on all preprocessed sequences
python run_alphafold_inference.py \
  --output_dir=/path/to/output \
  --data_dir=/path/to/alphafold/data \
  --model_preset=monomer \
  --use_gpu_relax=true
```

## Example: Different Model Presets

```bash
# Preprocess once
python run_alphafold_preprocess.py --fasta_paths=target.fasta ...

# Run with different model presets using same features
python run_alphafold_inference.py --model_preset=monomer ...
python run_alphafold_inference.py --model_preset=monomer_ptm ...
```

## Notes

- Features are saved as `features.pkl` in each target directory
- The inference script automatically finds all preprocessed targets
- Both scripts maintain compatibility with original AlphaFold outputs
- Preprocessing typically takes 30-90 minutes depending on sequence length
- Inference typically takes 5-30 minutes depending on sequence length and GPU