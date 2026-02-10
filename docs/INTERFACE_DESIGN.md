# scVAT Pipeline Interface Design

## Executive Summary

The scVAT pipeline provides a unified interface for processing both long-read (Oxford Nanopore/PacBio) and short-read (Illumina) single-cell RNA-seq data. The interface is designed around a single parameter (`--input_type`) that governs workflow branching while maintaining consistent output formats across platforms.

## Core Interface: `--input_type` Parameter

### Purpose
The `--input_type` parameter is the primary control mechanism that determines which specialized workflow path is executed. This design ensures platform-specific optimizations while maintaining a unified framework.

### Options
- `long_read`: For Oxford Nanopore or PacBio long-read sequencing data
- `short_read`: For Illumina paired-end short-read sequencing data

### Default
- `long_read` (maintains backward compatibility)

## Input Interface

### Samplesheet Format

The pipeline accepts different samplesheet formats based on `input_type`:

#### Long-Read Format
```csv
sample,fastq,cell_count
SAMPLE1,/path/to/reads.fastq.gz,1000
```

#### Short-Read Format
```csv
sample,fastq_1,fastq_2,cell_count
SAMPLE1,/path/to/R1.fastq.gz,/path/to/R2.fastq.gz,1000
```

The pipeline automatically validates the samplesheet format using the `nf-schema` plugin and the schema defined in `assets/schema_input.json`.

## Workflow-Specific Parameters

### Long-Read Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `barcode_format` | string | Yes* | 10X barcode format (10X_3v3, 10X_3v4, 10X_5v2, 10X_5v3) |
| `whitelist` | file | No | Custom barcode whitelist (overrides barcode_format) |
| `dedup_tool` | string | No | Deduplication tool: 'umitools' or 'picard' (default: 'umitools') |

*Required if `whitelist` is not provided

### Short-Read Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `barcode_length` | integer | Yes | Length of cell barcode in bp (default: 16 for 10X) |
| `umi_length` | integer | Yes | Length of UMI in bp (default: 12 for 10X) |
| `dedup_tool` | string | Fixed | Always 'umitools' (mandatory for short-read) |

## Unified Parameters

These parameters work identically for both workflows:

| Parameter | Type | Description |
|-----------|------|-------------|
| `genome_fasta` | file | Reference genome FASTA file |
| `gtf` | file | GTF annotation file |
| `transcript_fasta` | file | Transcriptome FASTA (for Oarfish) |
| `quantifier` | string | Quantification tools: 'isoquant', 'oarfish', or comma-separated |
| `alignment_mode` | string | Alignment mode: 'splice' (genome) or 'wgs' (transcriptome) |
| `skip_qc` | boolean | Skip all QC steps |
| `skip_seurat` | boolean | Skip Seurat QC |
| `skip_multiqc` | boolean | Skip MultiQC report |
| `skip_dedup` | boolean | Skip deduplication (not recommended for short-read) |

## Output Interface

### Unified Output Structure

Both workflows produce identical output structures:

```
<outdir>/
├── <sample_id>/
│   ├── genome/              # Genome alignment results
│   │   ├── vat/             # VAT alignment BAM files
│   │   ├── barcode_tagged/  # BAM files with CB/UB tags
│   │   ├── dedup_*/         # Deduplicated BAM files
│   │   ├── isoquant/        # IsoQuant count matrices
│   │   └── seurat/          # Seurat QC outputs
│   ├── transcriptome/      # Transcriptome alignment results
│   │   └── [same structure]
│   └── qc/                  # QC reports
│       ├── fastqc/          # FastQC reports
│       ├── nanoplot/        # NanoPlot reports (long-read only)
│       ├── rseqc/           # RSeQC reports
│       └── nanocomp/        # NanoComp reports
└── multiqc/                 # MultiQC aggregated report
    └── multiqc_report.html
```

### BAM File Tags

All BAM files include standard 10X Genomics tags:

- **CB**: Corrected cell barcode (whitelist-matched)
- **UB**: Corrected UMI sequence
- **CR**: Raw barcode sequence
- **CY**: Barcode quality scores
- **UR**: Raw UMI sequence
- **UY**: UMI quality scores

### Count Matrix Formats

1. **MatrixMarket Format** (`.mtx.gz`)
   - Compatible with Seurat, Scanpy, and other tools
   - Includes `features.tsv` and `barcodes.tsv`

2. **HDF5 Format** (future enhancement)
   - Faster I/O for large datasets
   - Direct compatibility with Scanpy

### QC Metrics

#### Single-Cell Metrics (from Seurat)
- Estimated cell number
- Mean reads per cell
- Median features per cell
- Total number of features
- **Mean mitochondrial read percentage** (newly added)

#### Alignment Metrics (from SAMtools)
- Mapping rate
- Read distribution statistics
- Chromosome coverage

#### Feature Metrics (from RSeQC)
- Genomic feature distribution
- Splice junction usage
- Read distribution across gene regions

#### Barcode Metrics
- **Long-read**: Barcode rank plots from BLAZE
- **Short-read**: Knee-point detection from UMI-tools

## Quality Control Interface

### Multi-Stage QC

The pipeline performs QC at multiple stages:

1. **Raw Read QC**: FastQC, NanoPlot (long-read), NanoComp
2. **Post-Trim QC**: FastQC, NanoPlot (long-read), NanoComp
3. **Post-Extraction QC**: FastQC, NanoPlot (long-read), NanoComp
4. **Post-Alignment QC**: SAMtools, RSeQC, NanoComp
5. **Post-Quantification QC**: Seurat metrics and plots

### QC Reports

All QC metrics are aggregated in the MultiQC report, which includes:
- Summary statistics
- Interactive plots
- Tool-specific sections
- Cross-sample comparisons

## Workflow Branching Logic

### Implementation

The branching logic is implemented in `workflows/scnanoseq.nf`:

```groovy
if (params.input_type == 'short_read') {
    // Short-read workflow
    // 1. UMI-tools whitelist
    // 2. UMI-tools extract
    // 3. PROCESS_SHORTREAD_SCRNA
} else {
    // Long-read workflow
    // 1. BLAZE barcode detection
    // 2. PREEXTRACT_FASTQ
    // 3. CORRECT_BARCODES
    // 4. PROCESS_LONGREAD_SCRNA
}
```

### Key Differences

| Aspect | Long-Read | Short-Read |
|--------|-----------|------------|
| Barcode Detection | BLAZE | UMI-tools whitelist |
| Barcode Extraction | Custom script | UMI-tools extract |
| Alignment Mode | VAT `--long` + `--splice`/`--wgs` | VAT `--splice`/`--wgs` (no `--long`) |
| Deduplication | Optional (UMI-tools or Picard) | Mandatory (UMI-tools only) |
| QC Tools | FastQC, NanoPlot, NanoComp, ToulligQC | FastQC |

## Error Handling and Validation

### Input Validation

1. **Samplesheet Validation**: 
   - Schema validation via `nf-schema` plugin
   - Format checking (long-read vs short-read)
   - File existence verification

2. **Parameter Validation**:
   - Required parameters checked based on `input_type`
   - Incompatible parameter combinations rejected
   - Default values applied when appropriate

### Error Messages

The pipeline provides clear error messages for:
- Missing required parameters
- Invalid samplesheet format
- File not found errors
- Incompatible parameter combinations

## Extension Points

### Adding New Quantifiers

1. Create quantifier module in `modules/local/`
2. Add to `quantifier` parameter enum
3. Add to workflow branching logic
4. Update output documentation

### Adding New QC Tools

1. Create QC module in `modules/nf-core/` or `modules/local/`
2. Add to appropriate QC subworkflow
3. Add to MultiQC configuration
4. Update documentation

### Custom Barcode Formats

1. Provide custom whitelist via `--whitelist` parameter
2. Or extend `barcode_format` enum in schema
3. Update BLAZE/UMI-tools configuration

## Best Practices

### For Long-Read Data

1. Always specify `barcode_format` or provide `whitelist`
2. Use `skip_trimming=false` for quality filtering
3. Consider using both IsoQuant and Oarfish for comprehensive quantification
4. Review BLAZE barcode rank plots to assess library quality

### For Short-Read Data

1. Ensure `barcode_length` and `umi_length` match your library prep
2. Deduplication is mandatory - do not skip
3. Use `skip_trimming=true` if reads are already trimmed
4. Review UMI-tools whitelist to assess cell recovery

### General Recommendations

1. Always run with `--skip_multiqc=false` for comprehensive QC
2. Use `--skip_seurat=false` for single-cell metrics
3. Review MultiQC report before downstream analysis
4. Check BAM tags (CB, UB) for proper barcode assignment
5. Validate count matrices in Seurat/Scanpy before proceeding

## Future Enhancements

1. **HDF5 Output**: Direct HDF5 matrix export
2. **Batch Correction**: Built-in batch effect correction
3. **Interactive QC**: Web-based QC dashboard
4. **Real-time Monitoring**: Progress tracking and resource monitoring
5. **Cloud Integration**: Native support for cloud storage backends

## References

- [Nextflow Documentation](https://www.nextflow.io/docs/latest/)
- [nf-core Guidelines](https://nf-co.re/developers/guidelines)
- [10X Genomics BAM Tags](https://support.10xgenomics.com/single-cell-gene-expression/software/pipelines/latest/output/bam)
- [Seurat Documentation](https://satijalab.org/seurat/)
- [Scanpy Documentation](https://scanpy.readthedocs.io/)
