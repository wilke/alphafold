#!/bin/bash
# Quick validation script to check if we're ready for full split pipeline testing

set -e

DB_DIR="/homes/wilke/databases"
CONTAINER_DIR="/scratch/alphafold/containers"

echo "=== Pre-Test Validation ==="
echo ""

# Check containers
echo "1. Container Status:"
for container in alphafold_ubuntu20.sif alphafold_ubuntu22.sif; do
    if [ -f "$CONTAINER_DIR/$container" ]; then
        size=$(ls -lah "$CONTAINER_DIR/$container" | awk '{print $5}')
        echo "  ✓ $container ($size)"
    else
        echo "  ✗ $container (missing)"
    fi
done
echo ""

# Check database copying status
echo "2. Database Status:"
total_expected=7
databases_ready=0

for db in bfd mgnify uniref90 uniref30 pdb70 pdb_mmcif params; do
    if [ -d "$DB_DIR/$db" ]; then
        size=$(du -sh "$DB_DIR/$db" 2>/dev/null | cut -f1)
        echo "  ✓ $db ($size)"
        ((databases_ready++))
    else
        echo "  ⏳ $db (copying...)"
    fi
done

echo ""
echo "Database Progress: $databases_ready/$total_expected ready"

# Check preprocessing script availability
echo ""
echo "3. Container Preprocessing Capability:"
for container in "$CONTAINER_DIR/alphafold_ubuntu20.sif" "$CONTAINER_DIR/alphafold_ubuntu22.sif"; do
    if [ -f "$container" ]; then
        container_name=$(basename "$container")
        if apptainer exec "$container" test -f /app/alphafold/run_alphafold_preprocess.py 2>/dev/null; then
            echo "  ✓ $container_name has preprocessing script"
        else
            echo "  ✗ $container_name missing preprocessing script"
        fi
    fi
done

# Check disk space
echo ""
echo "4. Storage Status:"
available_gb=$(df /scratch | tail -1 | awk '{print int($4/1024/1024)}')
echo "  Available space on /scratch: ${available_gb}GB"

if [ $available_gb -gt 100 ]; then
    echo "  ✓ Sufficient space for test outputs"
else
    echo "  ⚠️  Low disk space - monitor during testing"
fi

# Overall readiness assessment
echo ""
echo "=== READINESS ASSESSMENT ==="

ready_for_testing=true

if [ $databases_ready -ge 4 ]; then
    echo "✓ Databases: Ready (minimum required databases available)"
else
    echo "⏳ Databases: Waiting (need at least bfd, mgnify, uniref90, params)"
    ready_for_testing=false
fi

if [ -f "$CONTAINER_DIR/alphafold_ubuntu20.sif" ] && [ -f "$CONTAINER_DIR/alphafold_ubuntu22_fixed.sif" ]; then
    echo "✓ Containers: Ready"
else
    echo "✗ Containers: Missing"
    ready_for_testing=false
fi

if [ $available_gb -gt 100 ]; then
    echo "✓ Storage: Ready"
else
    echo "⚠️  Storage: Limited"
fi

echo ""
if [ "$ready_for_testing" = true ]; then
    echo "🚀 READY FOR TESTING!"
    echo "   Run: /scratch/alphafold/test_split_pipeline_fixed.sh quick"
    echo "   (Use 'quick' for 1VII only, omit for all proteins)"
else
    echo "⏳ NOT READY - Wait for database copying to complete"
    echo "   Re-run this script to check progress"
fi