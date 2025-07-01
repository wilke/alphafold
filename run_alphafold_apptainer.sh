#!/bin/bash

# Script to run AlphaFold using the Apptainer container
# This handles library path issues and provides a clean interface

# Check if container exists
if [ ! -f "/scratch/alphafold.sif" ]; then
    echo "Error: AlphaFold container not found at /scratch/alphafold.sif"
    echo "Please build it first using: apptainer build --fakeroot /scratch/alphafold.sif alphafold_apptainer.def"
    exit 1
fi

# Set default paths
DATABASES="${ALPHAFOLD_DATABASES:-/nfs/ml_lab/projects/ml_lab/cepi/alphafold/databases}"
OUTPUT_DIR="${OUTPUT_DIR:-/scratch/alphafold_output}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Print usage
if [ "$#" -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 <fasta_file> [additional_alphafold_args]"
    echo ""
    echo "Environment variables:"
    echo "  ALPHAFOLD_DATABASES - Path to AlphaFold databases (default: $DATABASES)"
    echo "  OUTPUT_DIR - Output directory (default: $OUTPUT_DIR)"
    echo "  CUDA_VISIBLE_DEVICES - GPU to use (default: 0)"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/sequence.fasta --model_preset=monomer --db_preset=reduced_dbs"
    exit 0
fi

FASTA_PATH="$1"
shift

# Check if fasta file exists
if [ ! -f "$FASTA_PATH" ]; then
    echo "Error: FASTA file not found: $FASTA_PATH"
    exit 1
fi

# Get absolute path
FASTA_PATH=$(realpath "$FASTA_PATH")
FASTA_DIR=$(dirname "$FASTA_PATH")
FASTA_NAME=$(basename "$FASTA_PATH")

# Set CUDA device
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

echo "Running AlphaFold with:"
echo "  FASTA: $FASTA_PATH"
echo "  Databases: $DATABASES"
echo "  Output: $OUTPUT_DIR"
echo "  GPU: $CUDA_VISIBLE_DEVICES"
echo ""

# Run AlphaFold in container with proper library paths
apptainer exec --nv \
    --bind "$DATABASES:/data:ro" \
    --bind "$FASTA_DIR:/input:ro" \
    --bind "$OUTPUT_DIR:/output" \
    --env LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
    /scratch/alphafold.sif \
    /opt/conda/bin/python /app/alphafold/run_alphafold.py \
        --fasta_paths="/input/$FASTA_NAME" \
        --data_dir=/data \
        --output_dir=/output \
        --uniref90_database_path=/data/uniref90/uniref90.fasta \
        --mgnify_database_path=/data/mgnify/mgy_clusters_2022_05.fa \
        --template_mmcif_dir=/data/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=/data/pdb_mmcif/obsolete.dat \
        --bfd_database_path=/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
        --small_bfd_database_path=/data/small_bfd/bfd-first_non_consensus_sequences.fasta \
        --pdb70_database_path=/data/pdb70/pdb70 \
        --uniref30_database_path=/data/uniref30/UniRef30_2021_03 \
        --max_template_date=2022-01-01 \
        --use_gpu_relax \
        "$@"