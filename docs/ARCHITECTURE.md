# scVAT Pipeline Architecture

## Overview

The scVAT pipeline is a dual-pathway single-cell RNA-seq analysis framework that supports both long-read (Oxford Nanopore/PacBio) and short-read (Illumina) sequencing platforms. The architecture is governed by the `--input_type` parameter, which branches into specialized workflows while maintaining a unified output structure.

## Core Design Principles

1. **Unified Framework**: Both pathways converge to produce standardized output formats (BAM tags, count matrices) compatible with existing single-cell ecosystems (Seurat, Scanpy).
2. **Platform-Specific Optimization**: Each pathway addresses platform-specific requirements (error rates, barcode structures) while maintaining consistency.
3. **Comprehensive QC**: Multi-stage quality control from raw reads to post-quantification metrics.
4. **Reproducibility**: All steps are containerized and version-controlled.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    INPUT VALIDATION                          │
│  - Samplesheet parsing (long-read vs short-read)             │
│  - Schema validation (nf-schema plugin)                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  --input_type        │
            │  Parameter           │
            └──────────┬───────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌───────────────┐           ┌──────────────────┐
│  LONG-READ    │           │   SHORT-READ      │
│  Workflow     │           │   Workflow        │
└───────┬───────┘           └────────┬──────────┘
        │                            │
        │                            │
        ▼                            ▼
┌─────────────────────────────────────────────────────────────┐
│              UNIFIED POST-ALIGNMENT PROCESSING             │
│  - BAM tagging (CB, UB tags)                                │
│  - Deduplication                                            │
│  - Quantification (IsoQuant/Oarfish)                         │
│  - QC metrics (RSeQC, SAMtools, Seurat)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              UNIFIED OUTPUT & REPORTING                      │
│  - Count matrices (MatrixMarket, HDF5)                     │
│  - MultiQC report                                           │
│  - Single-cell metrics                                      │
└─────────────────────────────────────────────────────────────┘
```

## Long-Read Workflow (`--input_type long_read`)

### Stage 1: Initial Quality Assessment
**Tools**: FastQC, NanoPlot, NanoComp, ToulligQC

- **Purpose**: Comprehensive assessment of raw read quality
- **Outputs**: 
  - Read length distributions
  - Quality score distributions
  - Base composition plots
  - Read count statistics

### Stage 2: Quality-Based Filtering
**Tool**: Nanofilt

- **Purpose**: Remove truncated or low-quality reads
- **Parameters**:
  - `--min_length`: Minimum read length
  - `--min_q_score`: Minimum average quality score
- **Output**: Filtered FASTQ files

### Stage 3: Post-Trim QC
**Tools**: FastQC, NanoPlot, NanoComp, ToulligQC

- **Purpose**: Validate filtering effectiveness
- **Outputs**: QC metrics for filtered reads

### Stage 4: Barcode Detection
**Tool**: BLAZE

- **Purpose**: Identify cellular barcodes and UMIs from long reads
- **Input**: 
  - Filtered FASTQ
  - Whitelist (10X format or custom)
- **Output**: 
  - Detected barcodes with counts
  - Barcode rank plots (knee plot visualization)
  - Whitelist of valid barcodes

### Stage 5: Barcode Extraction
**Script**: `bin/pre_extract_barcodes.py`

- **Purpose**: Parse FASTQ into R1 (barcode+UMI) and R2 (transcript) format
- **Output**: Split FASTQ files with barcode/UMI in headers

### Stage 6: Barcode Correction
**Script**: `bin/correct_barcodes.py`

- **Purpose**: Error correction using Hamming distance (max edit distance = 1)
- **Method**: Trie-based whitelist matching with probability scoring
- **Output**: Corrected barcode/UMI information (TSV)

### Stage 7: Post-Extraction QC
**Tools**: FastQC, NanoPlot, NanoComp, ToulligQC

- **Purpose**: Validate barcode extraction quality
- **Outputs**: QC metrics for extracted reads

### Stage 8: Alignment
**Tool**: VAT (Versatile Alignment Tool)

- **Mode**: Long-read optimized (`--long` flag)
- **Strategy**: Minimizer-based seeding with adaptive banding
- **Modes**:
  - Genome alignment: Splice-aware (`--splice`)
  - Transcriptome alignment: Whole-genome (`--wgs`)
- **Output**: Sorted, indexed BAM files

### Stage 9: Post-Alignment QC
**Tools**: SAMtools, RSeQC, NanoComp

- **Metrics**:
  - Mapping rates
  - Genomic feature distributions
  - Splice junction usage
  - Read distribution across genomic regions
- **Outputs**: 
  - Flagstat statistics
  - RSeQC read distribution reports
  - NanoComp BAM comparisons

### Stage 10: Barcode Tagging
**Script**: `bin/tag_barcodes.py`

- **Purpose**: Add standard 10X Genomics SAM tags
- **Tags**:
  - `CB`: Corrected barcode
  - `UB`: Corrected UMI
  - `CR`: Raw barcode sequence
  - `CY`: Raw barcode quality
  - `UR`: Raw UMI sequence
  - `UY`: Raw UMI quality
- **Input**: 
  - Aligned BAM
  - Corrected barcode information (from Stage 6)
- **Output**: Tagged BAM files

### Stage 11: Deduplication
**Tools**: UMI-tools OR Picard MarkDuplicates

- **Options**:
  - UMI-tools: UMI-based deduplication
  - Picard: Position-based deduplication
- **Output**: Deduplicated BAM files

### Stage 12: Quantification
**Tools**: IsoQuant, Oarfish

- **IsoQuant**:
  - Gene-level quantification
  - Transcript-level quantification
  - Novel isoform discovery
  - Unannotated splice junction detection
- **Oarfish**:
  - Transcript-level quantification only
  - Probabilistic assignment
- **Output**: Count matrices (MatrixMarket format)

### Stage 13: Preliminary Single-Cell QC
**Tool**: Seurat

- **Metrics**:
  - Estimated cell number
  - Mean reads per cell
  - Median features per cell
  - Total number of features
  - Violin plots (nFeature, nCount)
  - Density plots
  - Feature scatter plots
- **Output**: 
  - QC plots (PNG)
  - Statistics (CSV)
  - Seurat object (RDS)

### Stage 14: MultiQC Aggregation
**Tool**: MultiQC

- **Purpose**: Aggregate all QC metrics into a single report
- **Includes**:
  - Raw read QC
  - Trimmed read QC
  - Post-extraction QC
  - Alignment statistics
  - Quantification summaries
  - Single-cell metrics

## Short-Read Workflow (`--input_type short_read`)

### Stage 1: Raw Read QC
**Tool**: FastQC

- **Purpose**: Assess paired-end read quality
- **Outputs**: 
  - Per-base quality scores
  - Sequence quality distributions
  - Adapter content
  - Overrepresented sequences

### Stage 2: Barcode Detection
**Tool**: UMI-tools whitelist

- **Purpose**: Identify valid cell barcodes from R1
- **Method**: Knee-point detection to distinguish true cells from empty droplets
- **Parameters**:
  - `--bc-pattern`: Barcode pattern (e.g., `N{16}N{12}` for 10X)
- **Output**: Whitelist of valid barcodes

### Stage 3: Barcode Extraction
**Tool**: UMI-tools extract

- **Purpose**: Move barcode and UMI from R1 to R2 Read ID header
- **Input**: 
  - R1 FASTQ (barcode/UMI)
  - R2 FASTQ (transcript)
  - Whitelist (from Stage 2)
- **Output**: R2 FASTQ with barcode/UMI in Read ID (format: `original_id_BARCODE_UMI`)

### Stage 4: Alignment
**Tool**: VAT (Versatile Alignment Tool)

- **Mode**: Standard alignment (no special short-read flag)
- **Strategy**: Hash-based seed-and-extend
- **Modes**:
  - Genome alignment: Splice-aware (`--splice`)
  - Transcriptome alignment: Whole-genome (`--wgs`)
- **Output**: Sorted, indexed BAM files

### Stage 5: Post-Alignment QC
**Tools**: SAMtools, RSeQC

- **Metrics**: Same as long-read workflow
- **Outputs**: Same as long-read workflow

### Stage 6: Barcode Tagging
**Script**: `bin/tag_barcodes.py` (with `--extract_from_readid` flag)

- **Purpose**: Extract barcode/UMI from Read ID and add as BAM tags
- **Method**: 
  - Parse Read ID: `original_id_BARCODE_UMI`
  - Correct barcode using whitelist (Hamming distance = 1)
  - Add CB and UB tags
- **Output**: Tagged BAM files

### Stage 7: Deduplication
**Tool**: UMI-tools dedup (MANDATORY)

- **Purpose**: Directional adjacency-based deduplication
- **Method**: UMI-based molecular counting
- **Note**: This step is mandatory for short-read data (cannot be skipped)
- **Output**: Deduplicated BAM files

### Stage 8: Quantification
**Tools**: IsoQuant, Oarfish

- **Focus**: Primarily gene-level matrices
- **Options**: Transcript-level estimation available
- **Output**: Count matrices (MatrixMarket format)

### Stage 9: Preliminary Single-Cell QC
**Tool**: Seurat

- **Metrics**: Same as long-read workflow
- **Outputs**: Same as long-read workflow

### Stage 10: MultiQC Aggregation
**Tool**: MultiQC

- **Purpose**: Aggregate all QC metrics
- **Includes**: Same as long-read workflow

## Unified Post-Alignment Processing

### BAM Tagging Standards

Both workflows produce BAM files with standard 10X Genomics tags:

- **CB** (Corrected Barcode): Whitelist-corrected cell barcode
- **UB** (Corrected UMI): Corrected UMI sequence
- **CR** (Raw Barcode): Original barcode sequence
- **CY** (Barcode Quality): Phred quality scores
- **UR** (Raw UMI): Original UMI sequence
- **UY** (UMI Quality): Phred quality scores

### Output Format Standards

1. **BAM Files**: Sorted, indexed, with standard tags
2. **Count Matrices**: 
   - MatrixMarket format (`.mtx.gz`)
   - Features file (`features.tsv`)
   - Barcodes file (`barcodes.tsv`)
   - HDF5 format (future enhancement)
3. **QC Reports**: 
   - MultiQC HTML report
   - Individual tool reports (FastQC, NanoPlot, RSeQC, etc.)
   - Seurat QC plots and statistics

## Single-Cell Metrics

### Calculated Metrics

1. **Estimated Cell Number**: Number of unique barcodes passing filters
2. **Mean Reads per Cell**: Total reads / estimated cells
3. **Median Features per Cell**: Median number of genes/transcripts detected
4. **Total Number of Features**: Total genes/transcripts detected
5. **Mitochondrial Read Percentage**: Percentage of reads mapping to mitochondrial genes (future enhancement)
6. **Barcode Rank Plots**: Visualization of barcode abundance distribution (from BLAZE for long-read, from UMI-tools for short-read)

### Visualization

- **Violin Plots**: Distribution of nFeature and nCount
- **Density Plots**: Log10-scaled distributions
- **Feature Scatter Plots**: nCount vs nFeature relationships
- **Barcode Rank Plots**: Knee plot visualization

## Cross-Platform Compatibility

### Seurat Integration

Both workflows produce Seurat-compatible outputs:
- Standard BAM tags (CB, UB)
- MatrixMarket count matrices
- Seurat RDS objects

### Scanpy Integration

Outputs are compatible with Scanpy:
- Standard BAM tags
- MatrixMarket format
- HDF5 format (future)

### Batch Effect Analysis

The unified output structure enables:
- Cross-platform comparisons
- Technical batch effect identification
- Biological variation assessment
- Systematic quality control

## Configuration Interface

### Key Parameters

```groovy
params {
    // Input type (governs workflow branching)
    input_type = 'long_read'  // or 'short_read'
    
    // Long-read specific
    barcode_format = '10X_3v3'  // Required for long-read
    whitelist = null  // Optional custom whitelist
    
    // Short-read specific
    barcode_length = 16  // Required for short-read
    umi_length = 12      // Required for short-read
    
    // Alignment
    alignment_mode = 'splice'  // or 'wgs'
    
    // Quantification
    quantifier = 'isoquant'  // or 'oarfish' or comma-separated
    
    // Deduplication
    dedup_tool = 'umitools'  // or 'picard' (long-read only)
    
    // QC options
    skip_qc = false
    skip_seurat = false
    skip_multiqc = false
}
```

### Samplesheet Format

**Long-read**:
```csv
sample,fastq,cell_count
SAMPLE1,/path/to/reads.fastq.gz,1000
```

**Short-read**:
```csv
sample,fastq_1,fastq_2,cell_count
SAMPLE1,/path/to/R1.fastq.gz,/path/to/R2.fastq.gz,1000
```

## Future Enhancements

1. **HDF5 Output Format**: Direct HDF5 matrix export for faster I/O
2. **Mitochondrial Percentage**: Automatic calculation and reporting
3. **Barcode Rank Plots**: Enhanced visualization for both workflows
4. **Batch Correction**: Built-in batch effect correction tools
5. **Integration Testing**: Automated cross-platform validation

## References

- VAT: Versatile Alignment Tool (https://github.com/xuan13hao/VAT)
- BLAZE: Barcode detection for long reads (https://github.com/shimlab/BLAZE)
- UMI-tools: UMI handling and deduplication (https://github.com/CGATOxford/UMI-tools)
- IsoQuant: Gene and transcript quantification (https://github.com/ablab/IsoQuant)
- Oarfish: Transcript-level quantification (https://github.com/COMBINE-lab/oarfish)
- Seurat: Single-cell analysis toolkit (https://github.com/satijalab/seurat)
