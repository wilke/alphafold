# AlphaFold Pipeline Overview

This document describes how AlphaFold processes input data to predict protein structures, including the multiple sequence alignment (MSA) generation, template search, and model inference stages.

## Table of Contents

1. [Input Requirements](#input-requirements)
2. [Pipeline Architecture](#pipeline-architecture)
3. [Multiple Sequence Alignment Generation](#multiple-sequence-alignment-generation)
4. [Template Search](#template-search)
5. [Model Presets](#model-presets)
6. [Database Requirements](#database-requirements)
7. [Output Structure](#output-structure)

---

## Input Requirements

### Primary Input

AlphaFold accepts **FASTA files** containing protein amino acid sequences:

```
>sequence_name
MKFLILLFNILCLFPVLAADNHGVGPQGASGVDPITFDINSNQTGVQLTLPLGAGKFGATHC
```

- **Single sequence**: Treated as monomer prediction
- **Multiple sequences in one file**: Treated as a multimer complex prediction
- Each FASTA file must have a unique basename (used to name output directories)

### Key Parameters

| Parameter | Description | Options |
|-----------|-------------|---------|
| `--fasta_paths` | Path(s) to input FASTA files | Required |
| `--max_template_date` | Cutoff date for template structures | e.g., `2022-01-01` |
| `--db_preset` | Database configuration | `full_dbs`, `reduced_dbs` |
| `--model_preset` | Model architecture to use | `monomer`, `monomer_casp14`, `monomer_ptm`, `multimer` |
| `--data_dir` | Path to downloaded databases | Required |
| `--output_dir` | Where to save results | Required |

---

## Pipeline Architecture

AlphaFold's prediction pipeline consists of three major stages:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INPUT: FASTA Sequence                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGE 1: MSA Generation                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐  │
│  │  JackHMMER  │  │  JackHMMER  │  │  HHBlits (full) or          │  │
│  │  UniRef90   │  │   MGnify    │  │  JackHMMER (reduced)        │  │
│  │  10k hits   │  │   501 hits  │  │  BFD/UniRef30 or Small BFD  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGE 2: Template Search                         │
│  ┌─────────────────────────┐  ┌─────────────────────────────────┐   │
│  │  HHSearch (monomer)     │  │  HMMSEARCH (multimer)           │   │
│  │  Database: PDB70        │  │  Database: PDB SeqRes           │   │
│  └─────────────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGE 3: Neural Network Inference                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Evoformer → Structure Module → Amber Relaxation            │    │
│  │  (5 models ranked by confidence)                            │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    OUTPUT: PDB Structures + Confidence Metrics      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Multiple Sequence Alignment Generation

MSAs are critical to AlphaFold's accuracy. They provide evolutionary information that reveals which residues co-evolve, indicating spatial proximity in the 3D structure.

### MSA Search Strategy

AlphaFold combines results from multiple sequence databases to build deep, diverse alignments:

#### Stage 1: UniRef90 Search

| Property | Value |
|----------|-------|
| **Tool** | JackHMMER (HMMER suite) |
| **Database** | UniRef90 |
| **Iterations** | 1 |
| **E-value** | 0.0001 |
| **Max sequences** | 10,000 |
| **Output format** | Stockholm (.sto) |

> **Source**: `uniref_max_hits: int = 10000` defined in `alphafold/data/pipeline.py:126`

**Purpose**: Generate initial high-quality MSA from clustered UniProt sequences. This MSA also seeds the template search.

#### Stage 2: MGnify Search

| Property | Value |
|----------|-------|
| **Tool** | JackHMMER |
| **Database** | MGnify |
| **Max sequences** | 501 |
| **Output format** | Stockholm (.sto) |

> **Source**: `mgnify_max_hits: int = 501` defined in `alphafold/data/pipeline.py:125`

**Purpose**: Add metagenomic sequences for increased evolutionary diversity, especially useful for proteins with limited representation in curated databases.

#### Stage 3: BFD Search (Database Preset Dependent)

**Option A: Full Databases (`full_dbs`)**

| Property | Value |
|----------|-------|
| **Tool** | HHBlits (HH-suite) |
| **Databases** | BFD + UniRef30 (searched together) |
| **Iterations** | 3 |
| **E-value** | 0.001 |
| **Max sequences** | 1,000,000 |
| **Output format** | A3M |

**Option B: Reduced Databases (`reduced_dbs`)**

| Property | Value |
|----------|-------|
| **Tool** | JackHMMER |
| **Database** | Small BFD |
| **Output format** | Stockholm (.sto) |

**Trade-off**: `reduced_dbs` is significantly faster but may produce slightly less accurate predictions for some targets.

### MSA Processing

After collection, MSAs are:
1. **Deduplicated** to remove redundant sequences
2. **Combined** into a unified feature representation
3. **Clustered** for efficient processing in the neural network

The final MSA features include:
- `msa`: The aligned sequences
- `deletion_matrix`: Gaps relative to query
- `msa_profile`: Position-specific amino acid frequencies

### Multimer-Specific MSA Processing

For protein complexes, an additional search is performed:

| Property | Value |
|----------|-------|
| **Tool** | JackHMMER |
| **Database** | Unclustered UniProt |
| **Max sequences** | 50,000 |
| **Purpose** | MSA pairing between chains |

This enables AlphaFold to identify co-evolutionary signals between different chains in a complex.

---

## Template Search

Templates are experimentally determined 3D structures of proteins that are evolutionarily related (homologous) to your query sequence. They provide direct structural information — essentially telling the model: *"Here's what a similar protein looks like in 3D."*

### What Templates Provide

| Source | Information Type |
|--------|------------------|
| **MSA** | Evolutionary co-variation (indirect structural signal) |
| **Templates** | Direct 3D coordinates from homologous structures |

Even templates with only 30-40% sequence identity can provide valuable geometric constraints, as core protein folds are often conserved.

### Template Search Strategy: Hybrid Approach

Template search uses a **hybrid approach** combining MSA sensitivity with query sequence alignment:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Step 1: Build Search Profile                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  UniRef90 MSA (from JackHMMER) → Sequence Profile           │    │
│  │  More sensitive than single sequence for detecting homologs │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 2: Search Structure Database                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  HHSearch (monomer) or HMMSEARCH (multimer)                 │    │
│  │  Input: MSA profile    Database: PDB70 or PDB SeqRes        │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 3: Align & Extract Features                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Template hits aligned to QUERY SEQUENCE (not MSA)          │    │
│  │  3D coordinates extracted from PDB mmCIF files              │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

> **Source**: `alphafold/data/pipeline.py:179-225`

| Step | Input Used | Purpose |
|------|------------|---------|
| **Search** (HHSearch/HMMSEARCH) | UniRef90 MSA as profile | More sensitive detection of distant homologs |
| **Hit Parsing** | Original input sequence | Align template hits to query |
| **Feature Generation** | Original input sequence | Extract coordinates aligned to query |

### Monomer Template Search

| Property | Value |
|----------|-------|
| **Tool** | HHSearch (HH-suite) |
| **Database** | PDB70 (PDB clustered at 70% identity) |
| **Input** | A3M format MSA from UniRef90 |
| **Output** | HHR format (template hits) |

### Multimer Template Search

| Property | Value |
|----------|-------|
| **Tool** | HMMSEARCH (HMMER suite) |
| **Database** | PDB SeqRes (all PDB sequences) |
| **Input** | Stockholm format MSA |
| **Output** | Stockholm format |

### Template Processing

For each template hit:
1. The alignment from HHSearch/HMMSEARCH maps query residues to template residues
2. Template coordinates are extracted from PDB mmCIF files
3. Features are generated including:
   - `template_aatype`: Amino acid types
   - `template_all_atom_positions`: 3D coordinates
   - `template_all_atom_masks`: Atom presence flags

The `--max_template_date` parameter filters templates to exclude structures released after the specified date, important for benchmarking and avoiding data leakage.

### Kalign: Handling Database Inconsistencies

**Kalign** is a fast sequence alignment tool used as a **fallback mechanism** during template processing — not in the primary pipeline.

#### When Kalign Is Used

| Database | Contains |
|----------|----------|
| **PDB70** | Clustered/processed sequences (may be outdated) |
| **mmCIF files** | Current authoritative structure files |

Sometimes the search database (PDB70) has a slightly different sequence than the actual mmCIF structure file due to:
- Database update timing differences
- Sequence corrections in the PDB
- Version mismatches

When this occurs, AlphaFold detects the mismatch and uses Kalign to realign:

```
PDB70 sequence:  M K F L I L L F N I L C L F P V L A A D
                         ↓ mismatch detected ↓
mmCIF sequence:  M K F L I L G S L F N I L C L F P V L A A D
                         ↓ Kalign realigns ↓
New mapping:     Coordinates correctly extracted despite version difference
```

> **Source**: `alphafold/data/templates.py:541-555` — `_realign_pdb_template_to_query()` function

This ensures robustness when template sequences don't exactly match between the search database and structure files.

#### Kalign Requirements
- Minimum sequence length: 6 residues
- Output format: A3M

### Template-Free Prediction

AlphaFold models 3-5 in the `monomer` preset **do not use templates** — they rely solely on MSA information. This is useful when:
- No homologous structures exist in the PDB
- You want to avoid bias from existing structures
- Testing the model's de novo folding capability

The final ranking combines predictions from both template-using and template-free models, selecting the best result by confidence score.

---

## Model Presets

AlphaFold provides four model presets optimized for different use cases:

### `monomer` (Default)

- **Models**: model_1, model_2, model_3, model_4, model_5
- **Ensemble**: 1× (single pass)
- **Use case**: Standard single-chain prediction
- **Notes**: Models 1-2 use templates; models 3-5 do not

### `monomer_casp14`

- **Models**: Same as monomer
- **Ensemble**: 8× (matches CASP14 competition)
- **Use case**: Maximum accuracy benchmarking
- **Notes**: Significantly slower due to ensembling

### `monomer_ptm`

- **Models**: model_1_ptm through model_5_ptm
- **Ensemble**: 1×
- **Use case**: When confidence metrics are important
- **Additional outputs**:
  - Predicted TM-score (pTM)
  - Predicted Aligned Error (PAE)

### `multimer`

- **Models**: model_1_multimer_v3 through model_5_multimer_v3
- **Ensemble**: 1×
- **Use case**: Protein complex prediction
- **Notes**: Requires additional databases (UniProt, PDB SeqRes)

### Model Architecture Summary

All models share the core architecture:

1. **Input Embeddings**: Process MSA and template features
2. **Evoformer**: 48 blocks of attention over MSA and pair representations
3. **Structure Module**: 8 iterations of invariant point attention
4. **Heads**: Predict coordinates, confidence (pLDDT), and optionally pTM/PAE

---

## Database Requirements

### Storage Summary

| Preset | Download Size | Uncompressed Size |
|--------|---------------|-------------------|
| `full_dbs` | 556 GB | 2.62 TB |
| `reduced_dbs` | 86 GB | 438 GB |

### Core Databases (All Presets)

| Database | Size | Purpose |
|----------|------|---------|
| **UniRef90** | ~80 GB | Initial MSA generation |
| **MGnify** | ~120 GB | Metagenomic sequences |
| **PDB mmCIF** | ~200 GB | Template structure coordinates |
| **PDB obsolete mapping** | <1 MB | Map obsolete PDB IDs |

### Full Database Preset

| Database | Size | Purpose |
|----------|------|---------|
| **BFD** | ~1.7 TB | Deep evolutionary search |
| **UniRef30** | ~200 GB | Used with BFD in HHBlits |

### Reduced Database Preset

| Database | Size | Purpose |
|----------|------|---------|
| **Small BFD** | ~17 GB | Faster alternative to BFD |

### Monomer-Specific

| Database | Size | Purpose |
|----------|------|---------|
| **PDB70** | ~56 GB | Template search via HHSearch |

### Multimer-Specific

| Database | Size | Purpose |
|----------|------|---------|
| **UniProt** | ~100 GB | MSA pairing between chains |
| **PDB SeqRes** | ~0.2 GB | Template search via HMMSEARCH |

### Download Commands

```bash
# Download all databases (full)
scripts/download_all_data.sh <DOWNLOAD_DIR>

# Download reduced databases
scripts/download_all_data.sh <DOWNLOAD_DIR> reduced_dbs

# Download individual databases
scripts/download_uniref90.sh <DOWNLOAD_DIR>
scripts/download_mgnify.sh <DOWNLOAD_DIR>
scripts/download_bfd.sh <DOWNLOAD_DIR>
scripts/download_pdb70.sh <DOWNLOAD_DIR>
```

---

## Output Structure

AlphaFold generates the following outputs for each prediction:

```
<output_dir>/<sequence_name>/
├── features.pkl              # Processed input features
├── msas/                     # Raw MSA files
│   ├── uniref90_hits.sto
│   ├── mgnify_hits.sto
│   └── bfd_hits.a3m
├── unrelaxed_model_*.pdb     # Raw neural network outputs
├── relaxed_model_*.pdb       # After Amber energy minimization
├── ranked_*.pdb              # Final structures (ranked by pLDDT)
├── result_model_*.pkl        # Full outputs including confidence
├── ranking_debug.json        # pLDDT scores for each model
└── timings.json              # Runtime breakdown by stage
```

### Key Output Files

| File | Description |
|------|-------------|
| `ranked_0.pdb` | Best predicted structure |
| `ranking_debug.json` | Confidence scores used for ranking |
| `result_model_*.pkl` | Contains pLDDT, pTM, PAE arrays |

### Confidence Metrics

| Metric | Range | Description |
|--------|-------|-------------|
| **pLDDT** | 0-100 | Per-residue confidence (stored in B-factor column) |
| **pTM** | 0-1 | Predicted TM-score (global fold confidence) |
| **PAE** | 0-∞ Å | Predicted aligned error (pairwise confidence) |

**pLDDT interpretation**:
- >90: High confidence
- 70-90: Moderate confidence
- 50-70: Low confidence
- <50: Very low confidence (often disordered regions)

---

## External Tool Dependencies

| Tool | Version | Source | Purpose |
|------|---------|--------|---------|
| JackHMMER | HMMER 3.3+ | hmmer.org | Iterative sequence search |
| HHBlits | HH-suite 3.3+ | github.com/soedinglab/hh-suite | Profile-profile search |
| HHSearch | HH-suite 3.3+ | github.com/soedinglab/hh-suite | Template search (monomer) |
| HMMSEARCH | HMMER 3.3+ | hmmer.org | Template search (multimer) |
| Kalign | 2.0+ | github.com/TimoLassmann/kalign | Sequence alignment |
| OpenMM | 7.5+ | openmm.org | Amber relaxation |

---

## References

- Jumper, J., Evans, R., Pritzel, A. et al. Highly accurate protein structure prediction with AlphaFold. Nature 596, 583-589 (2021).
- Evans, R., O'Neill, M., Pritzel, A. et al. Protein complex prediction with AlphaFold-Multimer. bioRxiv (2022).
