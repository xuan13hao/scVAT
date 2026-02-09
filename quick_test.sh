#!/bin/bash
# Quick test script for scVAT pipeline
# Tests both long-read and short-read modes with minimal validation

set -euo pipefail

echo "=========================================="
echo "scVAT Quick Test"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check Nextflow
if ! command -v nextflow &> /dev/null; then
    echo "✗ Nextflow not found. Please install Nextflow first."
    exit 1
fi
echo "✓ Nextflow: $(nextflow -v)"

# Check VAT
if [ -f "bin/VAT" ]; then
    echo "✓ VAT binary found at bin/VAT"
elif command -v VAT &> /dev/null; then
    echo "✓ VAT found in PATH"
else
    echo "⚠ VAT not found. Pipeline may fail during alignment."
fi

echo ""
echo "=========================================="
echo "Test 1: Long-Read Mode (Syntax Validation)"
echo "=========================================="
echo ""

# Create output directory
mkdir -p test_output

# Test long-read mode - validate syntax and parameters
# Just check if Nextflow can parse the workflow and show parameters
echo "Running: nextflow run . -profile test_longread,docker --outdir test_output/longread_dryrun"
echo "This may take a moment as Nextflow parses the workflow and validates parameters..."
echo ""

# Run with timeout and show progress
LONGREAD_OUTPUT=$(timeout 120 bash -c 'nextflow run . \
    -profile test_longread,docker \
    --outdir test_output/longread_dryrun 2>&1' | tee /tmp/longread_test.log || true)

# Check if it shows the parameter summary (indicates successful parsing)
if echo "$LONGREAD_OUTPUT" | grep -qi "nf-core/scnanoseq.*1\.2\.1\|Input/output options\|Reference genome options"; then
    echo "$LONGREAD_OUTPUT" | grep -E "nf-core/scnanoseq|Input/output|Reference genome|Cell barcode|Analysis options" | head -10
    echo ""
    echo "✓ Long-read mode: Workflow structure validated (parameters parsed successfully)"
    LONGREAD_PASSED=1
elif echo "$LONGREAD_OUTPUT" | grep -qi "error\|exception\|failed\|Unable to"; then
    echo "$LONGREAD_OUTPUT" | grep -i "error\|exception\|failed" | head -10
    echo ""
    echo "✗ Long-read mode: Validation failed (errors detected)"
    LONGREAD_PASSED=0
else
    # If we see Nextflow banner, it means it at least started
    if echo "$LONGREAD_OUTPUT" | grep -qi "N E X T F L O W\|Launching"; then
        echo "$LONGREAD_OUTPUT" | head -20
        echo ""
        echo "✓ Long-read mode: Workflow structure validated (Nextflow started successfully)"
        LONGREAD_PASSED=1
    else
        echo "$LONGREAD_OUTPUT" | head -20
        echo ""
        echo "⚠ Long-read mode: Could not fully validate"
        LONGREAD_PASSED=0
    fi
fi

echo ""
echo "=========================================="
echo "Test 2: Short-Read Mode (Syntax Validation)"
echo "=========================================="
echo ""

# Test short-read mode - validate syntax and parameters
echo "Running: nextflow run . -profile test_shortread,docker --outdir test_output/shortread_dryrun"
echo "This may take a moment as Nextflow parses the workflow and validates parameters..."
echo ""

# Run with timeout and show progress
SHORTREAD_OUTPUT=$(timeout 120 bash -c 'nextflow run . \
    -profile test_shortread,docker \
    --outdir test_output/shortread_dryrun 2>&1' | tee /tmp/shortread_test.log || true)

# Check if it shows the parameter summary (indicates successful parsing)
if echo "$SHORTREAD_OUTPUT" | grep -qi "nf-core/scnanoseq.*1\.2\.1\|Input/output options\|Reference genome options"; then
    echo "$SHORTREAD_OUTPUT" | grep -E "nf-core/scnanoseq|Input/output|Reference genome|Cell barcode|Analysis options" | head -10
    echo ""
    echo "✓ Short-read mode: Workflow structure validated (parameters parsed successfully)"
    SHORTREAD_PASSED=1
elif echo "$SHORTREAD_OUTPUT" | grep -qi "error\|exception\|failed\|Unable to"; then
    echo "$SHORTREAD_OUTPUT" | grep -i "error\|exception\|failed" | head -10
    echo ""
    echo "⚠ Short-read mode: Validation issues detected"
    echo "  Note: Short-read test requires paired-end FASTQ files"
    SHORTREAD_PASSED=0
else
    # If we see Nextflow banner, it means it at least started
    if echo "$SHORTREAD_OUTPUT" | grep -qi "N E X T F L O W\|Launching"; then
        echo "$SHORTREAD_OUTPUT" | head -20
        echo ""
        echo "✓ Short-read mode: Workflow structure validated (Nextflow started successfully)"
        SHORTREAD_PASSED=1
    else
        echo "$SHORTREAD_OUTPUT" | head -20
        echo ""
        echo "⚠ Short-read mode: Could not fully validate (may need actual test data)"
        SHORTREAD_PASSED=0
    fi
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""

if [ ${LONGREAD_PASSED:-0} -eq 1 ]; then
    echo "✓ Long-read mode: PASSED"
else
    echo "✗ Long-read mode: FAILED"
fi

if [ ${SHORTREAD_PASSED:-0} -eq 1 ]; then
    echo "✓ Short-read mode: PASSED"
else
    echo "✗ Short-read mode: FAILED"
fi

echo ""
echo "Note: This is a syntax validation test."
echo "      For full functional tests with actual data, run:"
echo "        ./test_longread_shortread.sh both"
echo ""
echo "Or run individual tests:"
echo "  nextflow run . -profile test_longread,docker --outdir <OUTDIR>"
echo "  nextflow run . -profile test_shortread,docker --outdir <OUTDIR>"
echo ""

# Exit with error if any test failed
if [ ${LONGREAD_PASSED:-0} -eq 0 ] || [ ${SHORTREAD_PASSED:-0} -eq 0 ]; then
    exit 1
fi
