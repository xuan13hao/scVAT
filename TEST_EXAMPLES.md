# scVAT Pipeline Test Examples

This document provides simple examples to test both long-read and short-read modes of the scVAT pipeline.

## Prerequisites

1. **Nextflow** installed (version >= 24.04.2)
2. **VAT binary** available in `bin/VAT` or in system PATH
3. **Docker** or **Singularity** for container execution

## Quick Test

### Option 1: Using the Test Script

Run the automated test script:

```bash
# Test both modes
./test_longread_shortread.sh both

# Test only long-read mode
./test_longread_shortread.sh long_read

# Test only short-read mode
./test_longread_shortread.sh short_read
```

### Option 2: Manual Testing

#### Test Long-Read Mode

```bash
nextflow run . \
    -profile test_longread,docker \
    --outdir test_output/longread
```

This will:
- Use the existing test dataset from nf-core/test-datasets
- Process as long-read data using BLAZE for barcode detection
- Align using VAT with long-read presets

#### Test Short-Read Mode

```bash
nextflow run . \
    -profile test_shortread,docker \
    --outdir test_output/shortread
```

This will:
- Use paired-end FASTQ files (R1: barcode/UMI, R2: transcript)
- Use UMI-tools whitelist for barcode detection
- Use UMI-tools extract to move barcode/UMI to Read ID
- Align using VAT with short-read presets
- Perform mandatory UMI-tools dedup

## Test Configuration Files

### Long-Read Test Config (`conf/test_longread.config`)

- `input_type = 'long_read'`
- Uses existing nf-core test dataset
- Barcode format: 10X_3v3
- Quantifier: isoquant

### Short-Read Test Config (`conf/test_shortread.config`)

- `input_type = 'short_read'`
- Requires paired-end FASTQ files
- Barcode length: 16bp
- UMI length: 12bp
- Quantifier: isoquant
- Deduplication: mandatory (cannot skip)

## Sample Sheets

### Long-Read Sample Sheet Format

```csv
sample,fastq,cell_count
SAMPLE1,sample1.fastq.gz,5000
SAMPLE2,sample2.fastq.gz,5000
```

### Short-Read Sample Sheet Format

```csv
sample,fastq_1,fastq_2,cell_count
SAMPLE1,sample1_R1.fastq.gz,sample1_R2.fastq.gz,5000
SAMPLE2,sample2_R1.fastq.gz,sample2_R2.fastq.gz,5000
```

Where:
- `fastq_1`: R1 file containing barcode and UMI sequences
- `fastq_2`: R2 file containing transcript sequences

## Expected Outputs

After running the tests, you should see:

### Long-Read Outputs:
- `test_output/longread/`
  - `vat/` - VAT alignment results
  - `barcode_tagged/` - BAM files with barcode tags
  - `dedup_umitools/` or `dedup_picard/` - Deduplicated BAM files
  - `isoquant/` or `oarfish/` - Count matrices
  - `multiqc/` - MultiQC report

### Short-Read Outputs:
- `test_output/shortread/`
  - `umitools_whitelist/` - Whitelist of valid barcodes
  - `umitools_extract/` - FASTQ with barcode/UMI in Read ID
  - `vat/` - VAT alignment results
  - `barcode_tagged/` - BAM files with CB and UB tags
  - `dedup_umitools/` - Deduplicated BAM files (mandatory)
  - `isoquant/` or `oarfish/` - Count matrices
  - `multiqc/` - MultiQC report

## Troubleshooting

### VAT Binary Not Found

If you see errors about VAT binary:
```bash
# Check if VAT exists
ls -lh bin/VAT

# Make it executable
chmod +x bin/VAT

# Or ensure VAT is in PATH
which VAT
```

### Short-Read Test Data Not Available

The short-read test uses placeholder URLs. You may need to:
1. Create your own test data
2. Update `assets/samplesheet/samplesheet_shortread_test.csv` with actual file paths
3. Or use the long-read test which has real test data available

### Container Issues

If you encounter container issues:
```bash
# Try with singularity instead of docker
nextflow run . -profile test_longread,singularity --outdir test_output

# Or use conda
nextflow run . -profile test_longread,conda --outdir test_output
```

## Validation

After running tests, check:

1. **Nextflow execution report**: `test_output/*/pipeline_info/execution_report.html`
2. **MultiQC report**: `test_output/*/multiqc/multiqc_report.html`
3. **BAM files**: Check that barcode tags (CB, UB) are present
4. **Count matrices**: Verify that gene/transcript counts are generated

## Notes

- The test configurations use minimal resources (4 CPUs, 15GB RAM) for quick testing
- For production runs, adjust resources in the config files
- Short-read mode requires UMI-tools dedup (cannot be skipped)
- Long-read mode can use either UMI-tools or Picard for deduplication
