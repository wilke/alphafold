# AlphaFold Split Pipeline Scaling Analysis

## Test Summary

All tests completed successfully on 2025-08-08 using AlphaFold Ubuntu 20.04 Apptainer container on H100 GPUs.

## Performance Scaling Results

| Protein | Length (aa) | Preprocessing (s) | Inference (s) | Total (s) | Features Size (MB) |
|---------|-------------|-------------------|---------------|-----------|-------------------|
| 1VII    | 36          | REUSED            | 460           | 460       | 0.94              |
| 1UBQ    | 76          | 1311              | 519           | 1830      | 2.44              |
| 1LYZ    | 130         | 1196              | 564           | 1760      | 8.20              |
| 1MBN    | 154         | 1253              | 574           | 1827      | 6.42              |

## Key Findings

### 1. Preprocessing Performance
- **Time complexity**: Nearly constant (~1200-1300s) regardless of protein size
- **Memory usage**: Consistent at ~44-46GB RAM
- **Bottleneck**: Database searches dominate (UniRef90 ~6min, MGnify ~9.5min, BFD ~5min)
- **Features size**: Scales with sequence length and MSA diversity

### 2. Inference Performance  
- **Time complexity**: Scales sub-linearly with sequence length
- **Memory usage**: Consistent at ~12-13GB RAM
- **GPU utilization**: Single GPU (H100) with full memory allocation
- **Scaling factor**: ~25% increase from 36aa to 154aa (460s → 574s)

### 3. Model Performance (per-model without compilation)
| Model | 1VII (36aa) | 1UBQ (76aa) | 1LYZ (130aa) | 1MBN (154aa) |
|-------|-------------|-------------|--------------|--------------|
| 1     | N/A         | 7.7s        | 9.5s         | 10.2s        |
| 2     | N/A         | 5.3s        | 7.1s         | 7.7s         |
| 3     | N/A         | 7.6s        | 9.2s         | 9.9s         |
| 4     | N/A         | 7.6s        | 9.2s         | 9.9s         |
| 5     | N/A         | 5.2s        | 6.8s         | 7.3s         |

### 4. Split Pipeline Benefits Demonstrated

1. **Feature Reuse**: 1VII saved 20 minutes by reusing preprocessed features
2. **Resource Separation**: CPU preprocessing (44GB) vs GPU inference (12GB)
3. **Scalability**: Different scaling characteristics allow optimized resource allocation
4. **Checkpointing**: Features.pkl enables recovery from failures

## Recommendations

1. **CPU Allocation**: Preprocessing needs 8+ cores and 48GB RAM
2. **GPU Allocation**: Single H100 GPU sufficient for monomer inference
3. **Batch Processing**: Group proteins by size for optimal GPU utilization
4. **Feature Caching**: Implement features.pkl caching for repeated predictions
5. **Pipeline Optimization**: 
   - Run preprocessing on CPU nodes
   - Queue inference jobs on GPU nodes
   - Parallelize multiple preprocessing jobs

## Performance Model

Based on the data, we can model performance as:
- Preprocessing time: ~1250s (constant)
- Inference time: 400 + 1.1 × sequence_length (seconds)
- Total time: 1650 + 1.1 × sequence_length (seconds)

This model suggests the split pipeline is most beneficial for:
- Batch processing of many proteins
- Repeated predictions on same sequences
- Resource-constrained environments
- Recovery from failures