# scVAT

**scVAT** is a Nextflow DSL2 pipeline for single-cell/single-nucleus RNA-seq analysis supporting both **long-read (Oxford Nanopore)** and **short-read (Illumina 10x Genomics)** data. It uses **VAT (Versatile Alignment Tool)** for alignment and follows nf-core conventions.

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A524.04.2-brightgreen.svg)](https://www.nextflow.io/)
[![Singularity](https://img.shields.io/badge/singularity-supported-blue.svg)](https://sylabs.io/docs/)
[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](https://www.docker.com/)

---

## Overview

| Feature | Long-Read (Nanopore) | Short-Read (Illumina) |
|---------|---------------------|----------------------|
| Barcode detection | BLAZE | UMI-tools whitelist |
| Alignment | VAT (splice/WGS mode) | VAT (splice/WGS mode) |
| Deduplication | UMI-tools or Picard (optional) | UMI-tools per-gene+per-cell (mandatory) |
| Quantifiers | `isoquant`, `oarfish` | `umitools_count` |
| QC | FastQC, NanoPlot, ToulligQC, RSeQC, MultiQC | FastQC, RSeQC, MultiQC |

---

## Quick Start

### Prerequisites

- [Nextflow](https://www.nextflow.io/) ≥ 24.04.2
- [Singularity](https://sylabs.io/docs/) or [Docker](https://www.docker.com/)
- VAT binary in `bin/` or on `$PATH`

### Installation

```bash
git clone https://github.com/xuan13hao/scVAT.git
cd scVAT
chmod +x bin/VAT
```

### Run Tests

```bash
# Long-read (Nanopore)
nextflow run . \
    -profile singularity \
    -c conf/test_memory_limit.config \
    --input test_data/longread/samplesheet_longread.csv \
    --input_type long_read \
    --genome_fasta test_data/longread/chr21_ref.fa \
    --gtf https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.gtf \
    --barcode_format 10X_3v3 \
    --quantifier isoquant \
    --outdir test_output/longread

# Short-read (Illumina 10x)
nextflow run . \
    -profile singularity \
    -c conf/test_memory_limit.config \
    --input test_data/shortread/samplesheet_shortread.csv \
    --input_type short_read \
    --genome_fasta test_data/shortread/chr21_ref.fa \
    --gtf https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.gtf \
    --barcode_length 16 \
    --umi_length 12 \
    --quantifier umitools_count \
    --outdir test_output/shortread
```

---

## Samplesheet Format

### Long-Read

```csv
sample,fastq,cell_count
SAMPLE1,/path/to/sample1.fastq.gz,5000
SAMPLE2,/path/to/sample2.fastq.gz,5000
```

Multiple rows with the same `sample` are merged before processing.

### Short-Read

```csv
sample,fastq_1,fastq_2,cell_count
SAMPLE1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,5000
SAMPLE2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,5000
```

- `fastq_1` (R1): contains barcode + UMI
- `fastq_2` (R2): contains the cDNA sequence (aligned)

---

## Pipeline Workflows

### Long-Read Workflow

```
Raw FASTQ
  → QC (FastQC / NanoPlot / ToulligQC)
  → Quality filtering (NanoFilt)
  → Barcode detection (BLAZE)
  → Barcode extraction and correction
  → VAT alignment (genome or transcriptome)
  → CB/UB BAM tagging
  → Optional deduplication (UMI-tools or Picard)
  → Quantification (IsoQuant and/or Oarfish)
  → MultiQC report
```

### Short-Read Workflow

```
R1 + R2 FASTQ
  → QC (FastQC)
  → Barcode whitelist generation (UMI-tools whitelist from R1)
  → Barcode + UMI extraction into read headers (UMI-tools extract)
  → VAT alignment of R2 (cDNA)
  → CB/UB BAM tagging (Hamming-distance ≤ 1 correction)
  → Gene assignment (featureCounts → XT BAM tag)
  → Per-gene + per-cell UMI deduplication (UMI-tools dedup)
  → Count matrix generation (UMI-tools count → TSV + MEX)
  → MultiQC report
```

> **Note**: NanoFilt, NanoPlot, ToulligQC, and NanoComp are Nanopore-specific tools and are automatically skipped for short-read mode.

---

## Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to samplesheet CSV |
| `--input_type` | `long_read` or `short_read` |
| `--gtf` | Gene annotation GTF file |
| `--quantifier` | Quantifier(s) to run (see below) |
| `--outdir` | Output directory |

### Reference Genome

| Parameter | Description |
|-----------|-------------|
| `--genome_fasta` | Reference genome FASTA (required for `isoquant` and `umitools_count`) |
| `--transcript_fasta` | Transcriptome FASTA (required for `oarfish`) |
| `--fasta_delimiter` | Delimiter in FASTA sequence IDs (default: space) |

### Barcode Options

| Parameter | Mode | Default | Description |
|-----------|------|---------|-------------|
| `--barcode_format` | long-read | — | 10x chemistry: `10X_3v3`, `10X_3v4`, `10X_5v2`, `10X_5v3` |
| `--barcode_length` | short-read | `16` | Cell barcode length in bp |
| `--umi_length` | short-read | `12` | UMI length in bp |
| `--whitelist` | both | — | Custom barcode whitelist (overrides built-in) |
| `--dedup_tool` | long-read | `umitools` | Dedup tool: `umitools` or `picard` |

**Built-in whitelists** (used when `--barcode_format` is set without `--whitelist`):

| Format | Chemistry |
|--------|-----------|
| `10X_3v3` | 10x 3′ v3 (3M-february-2018) |
| `10X_3v4` | 10x 3′ v4 / PEX (3M-3pgex-may-2023) |
| `10X_5v2` | 10x 5′ v2 (737K-august-2016) |
| `10X_5v3` | 10x 5′ v3 / PEX (3M-5pgex-jan-2023) |

### Quantifiers

| Value | Mode | Description |
|-------|------|-------------|
| `isoquant` | long-read | Gene + transcript counts via IsoQuant |
| `oarfish` | long-read | Transcript counts via Oarfish (requires `--transcript_fasta`) |
| `umitools_count` | short-read | Per-gene+per-cell UMI counts via featureCounts + UMI-tools |

Comma-separate to run multiple: `--quantifier isoquant,oarfish`

### Alignment

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--kmer_size` | `14` | Minimizer k-mer length for VAT |
| `--stranded` | — | Library strandness: `None`, `reverse`, `forward` |
| `--save_genome_secondary_alignment` | `false` | Save secondary genome alignments |
| `--save_transcript_secondary_alignment` | `true` | Save secondary transcriptome alignments |

### Read Filtering (long-read only)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--min_length` | `1` | Minimum read length (bp) |
| `--min_q_score` | `10` | Minimum average quality score |
| `--split_amount` | `0` | Split FASTQ into chunks for parallel processing (0 = disabled) |

### Skip Flags

| Flag | Description |
|------|-------------|
| `--skip_trimming` | Skip NanoFilt trimming (long-read only) |
| `--skip_qc` | Skip all QC steps |
| `--skip_fastqc` | Skip FastQC |
| `--skip_nanoplot` | Skip NanoPlot |
| `--skip_toulligqc` | Skip ToulligQC |
| `--skip_fastq_nanocomp` | Skip NanoComp on FASTQ |
| `--skip_bam_nanocomp` | Skip NanoComp on BAM |
| `--skip_rseqc` | Skip RSeQC read distribution |
| `--skip_seurat` | Skip Seurat QC |
| `--skip_dedup` | Skip deduplication (long-read only; short-read always deduplicates) |
| `--skip_multiqc` | Skip MultiQC report |
| `--skip_save_minimap2_index` | Do not publish VAT index files |

---

## Output Structure

```
results/
├── batch_qcs/
│   ├── nanocomp/fastq/               # NanoComp FASTQ comparison (long-read)
│   ├── read_counts/                  # Read counts across preprocessing steps
│   └── multiqc/
│       ├── raw_qc/                   # MultiQC: pre-processing QC
│       └── final_qc/                 # MultiQC: final QC
│
├── references/
│   ├── genome/vat_index/             # VAT genome index (if saved)
│   └── transcriptome/vat_index/      # VAT transcriptome index (if saved)
│
├── pipeline_info/                    # Execution reports and software versions
│
└── SAMPLE_ID/
    ├── genome/
    │   ├── bam/
    │   │   ├── original/             # VAT-aligned BAM
    │   │   ├── mapped_only/          # Filtered (mapped reads only)
    │   │   ├── barcode_tagged/       # CB/UB-tagged BAM
    │   │   └── dedup/                # Deduplicated BAM (long-read)
    │   ├── isoquant/                 # IsoQuant output + MEX matrices
    │   ├── featurecounts/            # featureCounts annotated BAM + summary (short-read)
    │   ├── dedup/                    # Deduplicated BAM (short-read)
    │   └── umitools_count/
    │       ├── *_counts.tsv.gz       # Long-format UMI count table
    │       └── *_mtx/
    │           ├── matrix.mtx        # MEX sparse matrix
    │           ├── barcodes.tsv      # Cell barcodes
    │           └── features.tsv      # Gene features
    │
    ├── transcriptome/
    │   ├── bam/                      # Transcript-aligned BAMs
    │   └── oarfish/                  # Oarfish transcript counts
    │
    └── qc/
        ├── fastqc/                   # FastQC HTML reports
        ├── nanoplot/                 # NanoPlot stats (long-read)
        ├── toulligqc/                # ToulligQC reports (long-read)
        ├── samtools/                 # Flagstat / idxstats / stats
        ├── rseqc/                    # RSeQC read distribution
        └── seurat_isoquant/          # Seurat QC metrics
```

The count matrices in `*_mtx/` are compatible with Seurat (`Read10X()`), scanpy (`sc.read_10x_mtx()`), and standard 10x Genomics loaders.

---

## Advanced Usage

### Resume a failed run

```bash
nextflow run . -resume [original parameters...]
```

### Large datasets — parallel FASTQ splitting (long-read)

```bash
--split_amount 500000   # split into 500k-read chunks
```

### Custom resource config

```groovy
// custom.config
process {
    withName: '.*:BLAZE' {
        cpus   = 30
        memory = '60.GB'
    }
    withName: '.*:VAT_ALIGN' {
        cpus   = 20
        memory = '40.GB'
    }
    withName: '.*:ISOQUANT' {
        cpus   = 30
        memory = '85.GB'
    }
}
```

```bash
nextflow run . -c custom.config [other parameters...]
```

### Default resource labels

| Label | CPUs | Memory | Time |
|-------|------|--------|------|
| `process_single` | 1 | 6 GB | 4 h |
| `process_low` | 2 | 12 GB | 4 h |
| `process_medium` | 6 | 36 GB | 8 h |
| `process_high` | 12 | 72 GB | 20 h |
| `process_long` | — | — | 60 h |
| `process_high_memory` | — | 200 GB | — |

Failed processes are retried once with scaled-up memory and CPU.

---

## Troubleshooting

### Out-of-memory errors

Use the provided memory-limit config or create your own:

```bash
-c conf/test_memory_limit.config
```

### BLAZE barcode detection fails

Check that `--barcode_format` matches your 10x kit. For poor-quality data or non-10x protocols, supply a custom whitelist:

```bash
--whitelist /path/to/whitelist.txt
```

### Short-read deduplication error: `--extract-umi-method=tag`

Ensure your modules.config for `QUANTIFY_SCRNA_SHORTREAD:UMITOOLS_DEDUP` includes `--extract-umi-method=tag` in `ext.args`. This is set by default in `conf/modules.config`.

### Pipeline hangs or hits time limits

Enable FASTQ splitting to parallelize long-read jobs:

```bash
--split_amount 500000
```

---

## Citations

If you use scVAT, please cite:

**VAT**
> Hao Xuan, Hongyang Sun, Xiangtao Liu, Hanyuan Zhang, Jun Zhang, Cuncong Zhong. *A general and extensible algorithmic framework to biological sequence alignment across scales and applications.* bioRxiv 2026.01.28.702355; doi: [10.64898/2026.01.28.702355](https://doi.org/10.64898/2026.01.28.702355)

**nf-core**
> Ewels PA, et al. *The nf-core framework for community-curated bioinformatics pipelines.* Nat Biotechnol. 2020. doi: [10.1038/s41587-020-0439-x](https://doi.org/10.1038/s41587-020-0439-x)

**Tools**: BLAZE, UMI-tools, IsoQuant, Oarfish, featureCounts (Subread), SAMtools, FastQC, NanoPlot, ToulligQC, NanoComp, RSeQC, MultiQC.

See [CITATIONS.md](CITATIONS.md) for full references.

---

**Pipeline version**: 1.2.1 | **Nextflow**: ≥ 24.04.2 | **Last updated**: 2026-02-20
