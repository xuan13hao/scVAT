# scVAT Pipeline Testing Guide

## Overview

The scVAT pipeline includes a comprehensive test framework to validate both long-read and short-read modes. This guide explains how to use the testing tools.

## Quick Start

### Quick Validation (Recommended First Step)

This validates syntax and configuration without running the pipeline:

```bash
./test_framework.sh both validate
```

This is fast (seconds) and checks:
- Prerequisites (Nextflow, VAT)
- Workflow syntax
- Configuration files
- Parameter validation

### Full Test Execution

To actually run the pipeline with test data:

```bash
# Test both modes with full execution
./test_framework.sh both full

# Or test individual modes
./test_framework.sh long_read full
./test_framework.sh short_read full
```

## Test Framework Options

### Test Modes

- `long_read`: Test long-read mode only
- `short_read`: Test short-read mode only
- `both`: Test both modes (default)

### Test Actions

- `validate`: Only validate syntax and configuration (fast, default)
- `run`: Run the pipeline (requires test data to exist)
- `full`: Generate test data, validate, and run (complete test)

## Test Scripts

### 1. `test_framework.sh` (Recommended)

Comprehensive test framework with multiple modes and actions.

**Usage:**
```bash
./test_framework.sh [mode] [action]
```

**Examples:**
```bash
# Quick validation of both modes
./test_framework.sh both validate

# Full test of long-read mode
./test_framework.sh long_read full

# Run short-read test (assumes data exists)
./test_framework.sh short_read run
```

### 2. `test_longread_local.sh`

Dedicated script for long-read testing with local data.

**Usage:**
```bash
./test_longread_local.sh
```

**What it does:**
1. Generates long-read test data (if needed)
2. Checks prerequisites
3. Runs the pipeline with `test_longread_local` profile

### 3. `test_shortread_local.sh`

Dedicated script for short-read testing with local data.

**Usage:**
```bash
./test_shortread_local.sh
```

**What it does:**
1. Generates short-read test data (if needed)
2. Checks prerequisites
3. Runs the pipeline with `test_shortread_local` profile

### 4. `quick_validate.sh`

Quick syntax validation only (no execution).

**Usage:**
```bash
./quick_validate.sh
```

## Test Data Generation

### Long-Read Test Data

```bash
./generate_longread_test_data.sh
```

Generates:
- `test_data/longread/test_longread.fastq.gz` - Simulated long reads
- `test_data/longread/whitelist.txt` - Cell barcode whitelist
- `test_data/longread/samplesheet_longread.csv` - Samplesheet

**Parameters:**
- Number of reads: 500
- Number of cells: 10
- Barcode length: 16 bp
- UMI length: 12 bp

### Short-Read Test Data

```bash
./generate_test_data.sh
```

Generates:
- `test_data/shortread/test_R1.fastq.gz` - R1 (barcode/UMI)
- `test_data/shortread/test_R2.fastq.gz` - R2 (transcript)
- `test_data/shortread/whitelist.txt` - Cell barcode whitelist
- `test_data/shortread/samplesheet_shortread.csv` - Samplesheet

## Test Profiles

### `test_longread_local`

Configuration for testing long-read mode with local data:
- Uses locally generated test data
- Reduced memory requirements
- Skips some optional steps for faster testing

**Usage:**
```bash
nextflow run . -profile test_longread_local,docker --outdir test_output
```

### `test_shortread_local`

Configuration for testing short-read mode with local data:
- Uses locally generated test data
- Reduced memory requirements
- Skips some optional steps for faster testing

**Usage:**
```bash
nextflow run . -profile test_shortread_local,docker --outdir test_output
```

## Expected Test Results

### Validation Test

Should show:
```
✓ Nextflow: nextflow version X.X.X
✓ VAT found at bin/VAT
✓ main.nf found
✓ workflows/scnanoseq.nf found
✓ nextflow.config found
✓ Nextflow syntax validation passed
✓ Long-read configuration valid
✓ Short-read configuration valid
✓ Workflow validation: PASSED
✓ Long-read mode: PASSED
✓ Short-read mode: PASSED
```

### Full Test Execution

Should produce:
- Test data in `test_data/`
- Pipeline outputs in `test_output/`
- MultiQC report
- BAM files with CB/UB tags
- Count matrices
- QC reports

## Troubleshooting

### VAT Not Found

**Error:** `⚠ VAT binary not found`

**Solution:**
1. Download VAT binary
2. Place it in `bin/VAT`
3. Or add VAT to your PATH

### Docker/Singularity Not Found

**Error:** `⚠ Neither Docker nor Singularity found`

**Solution:**
- Install Docker: https://docs.docker.com/get-docker/
- Or install Singularity: https://sylabs.io/docs/

### Test Data Generation Fails

**Error:** Python script errors

**Solution:**
- Ensure Python 3 is installed
- Check that required Python modules are available
- Verify write permissions in `test_data/` directory

### Pipeline Execution Fails

**Error:** Nextflow execution errors

**Solution:**
1. Check the log file in `test_output/`
2. Verify all prerequisites are installed
3. Check container engine is working: `docker run hello-world`
4. Review error messages in the log

### Memory Errors

**Error:** `Memory request X GB is larger than maximum Y GB`

**Solution:**
- Reduce test data size (modify generation scripts)
- Adjust memory limits in test config files
- Skip memory-intensive steps (e.g., `skip_seurat=true`)

## Test Output Structure

After running tests, you'll find:

```
test_output/
├── longread_YYYYMMDD_HHMMSS/
│   ├── dag.html              # Workflow DAG
│   ├── report.html           # Execution report
│   ├── trace.txt             # Execution trace
│   └── [pipeline outputs]
└── shortread_YYYYMMDD_HHMMSS/
    ├── dag.html
    ├── report.html
    ├── trace.txt
    └── [pipeline outputs]
```

## Continuous Integration

For CI/CD pipelines, use:

```bash
# Quick validation (fast, no containers needed)
./test_framework.sh both validate

# Or with explicit exit code checking
if ./test_framework.sh both validate; then
    echo "Tests passed"
else
    echo "Tests failed"
    exit 1
fi
```

## Best Practices

1. **Always validate first**: Run `validate` before `run` or `full`
2. **Check prerequisites**: Ensure Nextflow, VAT, and container engine are available
3. **Review logs**: Check log files if tests fail
4. **Clean up**: Remove old test outputs periodically
5. **Use appropriate profiles**: Use `test_*_local` profiles for local testing

## Customizing Tests

### Modifying Test Data Size

Edit the generation scripts:
- `generate_longread_test_data.sh`: Change `NUM_READS` and `NUM_CELLS`
- `generate_test_data.sh`: Change read count parameters

### Adjusting Memory Limits

Edit test config files:
- `conf/test_longread_local.config`
- `conf/test_shortread_local.config`

Modify the `process.resourceLimits` section.

### Skipping Steps

Add to test config:
```groovy
params {
    skip_seurat = true
    skip_multiqc = false
    skip_dedup = false
}
```

## Test Coverage

The test framework validates:

- [x] Workflow syntax
- [x] Configuration files
- [x] Parameter validation
- [x] Samplesheet parsing
- [x] Long-read workflow execution
- [x] Short-read workflow execution
- [x] Output generation
- [x] QC report generation

## Support

For issues or questions:
1. Check the logs in `test_output/`
2. Review the documentation in `docs/`
3. Check Nextflow logs: `.nextflow.log`
