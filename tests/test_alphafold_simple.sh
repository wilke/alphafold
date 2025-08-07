#!/bin/bash

# Simple test of AlphaFold with minimal settings

DATABASES="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases"
FASTA="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/data/seq.faa"
OUTPUT="/scratch/alphafold_test_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT"

echo "Testing AlphaFold with:"
echo "  FASTA: $FASTA"
echo "  Output: $OUTPUT"
echo ""

# Run with minimal required flags
CUDA_VISIBLE_DEVICES=0 apptainer exec --nv \
    --bind "$DATABASES:/data:ro" \
    --bind "$(dirname $FASTA):/input:ro" \
    --bind "$OUTPUT:/output" \
    --env LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
    /scratch/alphafold.sif \
    /opt/conda/bin/python /app/alphafold/run_alphafold.py \
        --fasta_paths="/input/$(basename $FASTA)" \
        --output_dir=/output \
        --data_dir=/data \
        --uniref90_database_path=/data/uniref90/uniref90.fasta \
        --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa \
        --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
        --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
        --pdb70_database_path=/data/pdb70/pdb70 \
        --uniref30_database_path=/data/uniref30/UniRef30_2021_03 \
        --model_preset=monomer \
        --db_preset=full_dbs \
        --benchmark=False \
        --use_gpu_relax=True \
        --max_template_date=2022-01-01 \
        --num_multimer_predictions_per_model=1 \
        --use_precomputed_msas=False

echo ""
echo "Output saved to: $OUTPUT"