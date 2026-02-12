# scVAT: Single-Cell RNA-seq Analysis Pipeline

**scVAT** is a scalable Nextflow DSL2 pipeline for analyzing single-cell/nuclei RNA-seq data from both **long-read (Oxford Nanopore)** and **short-read (Illumina)** platforms. The pipeline uses **VAT (Versatile Alignment Tool)** for alignment and follows nf-core best practices.

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A524.04.2-brightgreen.svg)](https://www.nextflow.io/)
[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](https://www.docker.com/)
[![Singularity](https://img.shields.io/badge/singularity-supported-blue.svg)](https://sylabs.io/docs/)

---

## Features

- ✅ **Dual-mode support**: Long-read (Nanopore) and short-read (Illumina)
- ✅ **VAT alignment**: Fast and accurate alignment for both read types
- ✅ **10X Genomics compatible**: BLAZE barcode detection for long reads, UMI-tools for short reads
- ✅ **Flexible quantification**: IsoQuant (gene/transcript) and Oarfish (transcript-only)
- ✅ **Comprehensive QC**: FastQC, NanoPlot, MultiQC, and Seurat metrics
- ✅ **Containerized**: Full Docker and Singularity support
- ✅ **Scalable**: Optimized for both small and large datasets

---

## Quick Start

### Prerequisites

- [Nextflow](https://www.nextflow.io/) ≥24.04.2
- [Docker](https://www.docker.com/) or [Singularity](https://sylabs.io/docs/)
- VAT binary (place in `bin/` directory or ensure it's in PATH)

### Installation

```bash
# Clone the repository
git clone https://github.com/xuan13hao/scVAT.git
cd scVAT

# Ensure VAT binary is available
chmod +x bin/VAT  # If VAT is in bin/

# Test the installation
./quick_test.sh
```

### Basic Usage

#### Long-Read Data (Oxford Nanopore)

```bash
nextflow run . \
    -profile singularity \
    --input samplesheet_longread.csv \
    --input_type long_read \
    --genome_fasta genome.fa \
    --gtf annotation.gtf \
    --barcode_format 10X_3v3 \
    --quantifier isoquant \
    --outdir results/longread
```

#### Short-Read Data (Illumina)

```bash
nextflow run . \
    -profile singularity \
    --input samplesheet_shortread.csv \
    --input_type short_read \
    --genome_fasta genome.fa \
    --gtf annotation.gtf \
    --quantifier isoquant \
    --outdir results/shortread
```

---

## Input Format

### Long-Read Samplesheet

Create a CSV file with single-end FASTQ files:

```csv
sample,fastq,cell_count
SAMPLE1,sample1_reads.fastq.gz,5000
SAMPLE2,sample2_reads.fastq.gz,5000
```

- Multiple rows with the same `sample` name will be merged
- `cell_count`: Expected number of cells for the sample

### Short-Read Samplesheet

Create a CSV file with paired-end FASTQ files:

```csv
sample,fastq_1,fastq_2,cell_count
SAMPLE1,sample1_R1.fastq.gz,sample1_R2.fastq.gz,5000
SAMPLE2,sample2_R1.fastq.gz,sample2_R2.fastq.gz,5000
```

- `fastq_1` (R1): Barcode and UMI sequences
- `fastq_2` (R2): Transcript sequences
- `cell_count`: Expected number of cells

---

## Pipeline Workflows

### Long-Read Workflow

```
FASTQ → QC (FastQC/NanoPlot) → Filter (NanoFilt) →
Barcode Detection (BLAZE) → Barcode Extraction/Correction →
VAT Alignment → BAM Tagging → Deduplication →
Quantification (IsoQuant/Oarfish) → MultiQC Report
```

**Key Steps:**
1. **QC**: FastQC, NanoPlot, NanoComp (optional)
2. **Filtering**: NanoFilt quality filtering
3. **Barcoding**: BLAZE detects 10X barcodes, custom scripts extract and correct
4. **Alignment**: VAT with splice-aware mode for genome, or WGS mode for transcriptome
5. **Tagging**: CB (cell barcode) and UB (UMI) tags added to BAM
6. **Deduplication**: UMI-tools or Picard (optional)
7. **Quantification**: IsoQuant and/or Oarfish
8. **Reporting**: MultiQC aggregates all QC metrics

### Short-Read Workflow

```
FASTQ (R1+R2) → QC (FastQC) →
Barcode Detection (UMI-tools whitelist) → Barcode Extraction (UMI-tools) →
VAT Alignment → BAM Tagging → Deduplication (mandatory) →
Quantification (IsoQuant/Oarfish) → MultiQC Report
```

**Key Steps:**
1. **QC**: FastQC on both R1 and R2
2. **Barcoding**: UMI-tools generates whitelist and extracts barcodes to read headers
3. **Alignment**: VAT optimized for short reads
4. **Tagging**: Extract CB/UB from read headers to BAM tags
5. **Deduplication**: UMI-tools (mandatory for short-read)
6. **Quantification**: IsoQuant and/or Oarfish
7. **Reporting**: MultiQC

---

## Key Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to samplesheet CSV |
| `--input_type` | `long_read` or `short_read` |
| `--genome_fasta` | Reference genome (for IsoQuant) |
| `--gtf` | Gene annotation GTF file |
| `--outdir` | Output directory |

### Optional

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--transcript_fasta` | null | Transcriptome FASTA (for Oarfish) |
| `--barcode_format` | null | 10X barcode format (`10X_3v3`, `10X_5v2`, etc.) |
| `--quantifier` | `isoquant` | Comma-separated: `isoquant`, `oarfish`, or `isoquant,oarfish` |
| `--dedup_tool` | `umitools` | Deduplication tool: `umitools` or `picard` |
| `--split_amount` | 0 | Split FASTQ into chunks (e.g., 500000) for faster processing |
| `--skip_trimming` | false | Skip NanoFilt trimming |
| `--skip_qc` | false | Skip all QC steps |
| `--skip_dedup` | false | Skip deduplication (long-read only) |
| `--skip_multiqc` | false | Skip MultiQC report generation |

---

## Output Structure

```
results/
├── multiqc/
│   ├── multiqc_report_raw.html          # Pre-processing QC
│   └── multiqc_report_final.html        # Final QC report
├── SAMPLE1/
│   ├── alignment/
│   │   ├── aligned.bam                  # Aligned reads
│   │   ├── aligned.bam.bai              # BAM index
│   │   └── flagstat.txt                 # Alignment stats
│   ├── quantification/
│   │   ├── isoquant/
│   │   │   ├── gene_counts.mtx          # Gene count matrix
│   │   │   └── transcript_counts.mtx    # Transcript count matrix
│   │   └── oarfish/
│   │       └── transcript_counts.mtx    # Oarfish transcript counts
│   └── qc/
│       ├── fastqc/                      # FastQC reports
│       └── nanoplot/                    # NanoPlot reports (long-read)
└── pipeline_info/
    ├── execution_report.html            # Nextflow execution report
    └── execution_timeline.html          # Execution timeline
```

---

## Testing

### Quick Validation

```bash
# Syntax and parameter validation only
./quick_test.sh
```

### Functional Tests

```bash
# Test with local data (requires less memory)
nextflow run . -profile test_longread_local,singularity --outdir test_output/longread --input_type long_read 
nextflow run . -profile test_shortread_local,singularity --outdir test_output/shortread --input_type short_read 

# Test with minimal configuration (skips optional QC)
nextflow run . -profile test_minimal,singularity --outdir test_output/minimal
```

---

## Troubleshooting

### Memory Issues

If processes fail with "insufficient memory" errors:

1. **Reduce memory requirements** with a custom config:
   ```groovy
   process {
       withName: '.*:SPLIT_FASTA' {
           memory = '4.GB'
       }
   }
   ```

2. **Use test profiles** designed for limited memory:
   ```bash
   -profile test_minimal,singularity
   ```

### Container Issues

**Podman/Docker cgroup errors**: Use Singularity instead:
```bash
-profile singularity  # Instead of -profile docker
```


### BLAZE Barcode Detection Fails

**Symptom**: "Failed to get whitelist" error with low percentage of valid reads

**Causes**:
- Test data lacks realistic 10X structure
- Incorrect barcode format specified
- Poor quality Nanopore data

**Solutions**:
```bash
# Use correct barcode format
--barcode_format 10X_3v3  # For 3' v3 chemistry
--barcode_format 10X_5v2  # For 5' v2 chemistry

# Or provide custom whitelist
--whitelist /path/to/custom_whitelist.txt
```

### Performance Optimization

For large datasets (PromethION):

```bash
# Enable FASTQ splitting for parallel processing
--split_amount 500000

# Increase resources in custom config
nextflow run . -c custom.config ...
```

**custom.config:**
```groovy
process {
    withName: '.*:BLAZE' {
        cpus = 30
        memory = '60.GB'
    }
    withName: '.*:VAT_ALIGN' {
        cpus = 20
        memory = '40.GB'
    }
    withName: '.*:ISOQUANT' {
        cpus = 30
        memory = '85.GB'
    }
}
```

### Deduplication Takes Too Long

```bash
# Enable FASTQ splitting
--split_amount 500000

# Or increase time limit
process {
    withName: '.*:CORRECT_BARCODES' {
        time = '15.h'
    }
}
```

## Advanced Usage

### Resume Failed Runs

```bash
nextflow run . -resume ...
```

### Custom Configuration

```bash
nextflow run . -c custom.config ...
```

### Skip Optional Steps

```bash
# Skip QC steps for faster processing
--skip_nanoplot --skip_toulligqc --skip_fastq_nanocomp --skip_bam_nanocomp

# Skip deduplication (long-read only)
--skip_dedup

# Skip Seurat QC
--skip_seurat
```
### Multiple Quantifiers
```bash
# Run both IsoQuant and Oarfish
--quantifier isoquant,oarfish \
--genome_fasta genome.fa \
--transcript_fasta transcriptome.fa
```
## Citations
If you use scVAT, please cite:
### VAT (Versatile Alignment Tool)
> Hao Xuan, Hongyang Sun, Xiangtao Liu, Hanyuan Zhang, Jun Zhang, Cuncong Zhong. *A general and extensible algorithmic framework to biological sequence alignment across scales and applications.* bioRxiv 2026.01.28.702355; doi: https://doi.org/10.64898/2026.01.28.702355
### nf-core Framework
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen. *The nf-core framework for community-curated bioinformatics pipelines.* Nat Biotechnol. 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x)

### Tools Used
- **BLAZE**: Barcode detection for long reads
- **UMI-tools**: Barcode handling for short reads
- **IsoQuant**: Gene and transcript quantification
- **Oarfish**: Fast transcript quantification
- **SAMtools**, **FastQC**, **NanoPlot**, **MultiQC**: Quality control
See [CITATIONS.md](CITATIONS.md) for complete citations.
---
## Support
For questions or issues:
- Open an issue on GitHub
- Review troubleshooting section above
---

**Pipeline Version**: 1.2.1
**Nextflow Required**: ≥24.04.2
**Last Updated**: 2026-02-10
