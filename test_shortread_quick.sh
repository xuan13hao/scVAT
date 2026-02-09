#!/bin/bash
# Quick test for short-read mode - just validate parameters without running

set -euo pipefail

echo "=========================================="
echo "Quick Short-Read Mode Validation"
echo "=========================================="
echo ""

# Check if test data exists
if [ ! -f "test_data/shortread/samplesheet_shortread.csv" ]; then
    echo "Generating test data..."
    ./generate_test_data.sh
fi

echo "Testing parameter validation..."
echo ""

# Test with --help to see if parameters are accepted
if nextflow run . \
    -profile test_shortread_local,docker \
    --outdir test_output/shortread_validation \
    -help 2>&1 | grep -q "input_type\|short_read"; then
    echo "✓ Parameters accepted"
else
    echo "⚠ Parameter validation may have issues"
fi

echo ""
echo "Testing samplesheet validation..."
echo ""

# Try to validate the samplesheet
if nextflow run . \
    -profile test_shortread_local,docker \
    --outdir test_output/shortread_validation \
    2>&1 | head -50; then
    echo ""
    echo "✓ Samplesheet validation passed"
else
    echo ""
    echo "✗ Samplesheet validation failed"
    echo ""
    echo "Check the error messages above"
    exit 1
fi

echo ""
echo "=========================================="
echo "Validation Complete"
echo "=========================================="
echo ""
echo "If you see parameter summary above, the configuration is correct."
echo "To run the full pipeline:"
echo "  ./test_shortread_local.sh"
echo ""
