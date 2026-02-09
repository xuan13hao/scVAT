#!/bin/bash
# Test script for long-read mode with locally generated test data

set -euo pipefail

echo "=========================================="
echo "Testing Long-Read Mode with Local Data"
echo "=========================================="
echo ""

# Step 1: Generate test data
echo "Step 1: Generating test data..."
if [ ! -f "test_data/longread/samplesheet_longread.csv" ]; then
    echo "Test data not found. Generating..."
    ./generate_longread_test_data.sh
else
    echo "✓ Test data already exists"
fi

# Step 2: Check prerequisites
echo ""
echo "Step 2: Checking prerequisites..."

if ! command -v nextflow &> /dev/null; then
    echo "✗ Nextflow not found"
    exit 1
fi
echo "✓ Nextflow: $(nextflow -v)"

if [ ! -f "bin/VAT" ] && ! command -v VAT &> /dev/null; then
    echo "⚠ VAT not found. Pipeline may fail during alignment."
else
    echo "✓ VAT found"
fi

# Step 3: Run the pipeline
echo ""
echo "=========================================="
echo "Step 3: Running Pipeline"
echo "=========================================="
echo ""

OUTDIR="test_output/longread_local_$(date +%Y%m%d_%H%M%S)"

echo "Output directory: $OUTDIR"
echo ""
echo "Command:"
echo "  nextflow run . \\"
echo "    -profile test_longread_local,docker \\"
echo "    --outdir $OUTDIR"
echo ""

read -p "Press Enter to start the pipeline, or Ctrl+C to cancel..."

nextflow run . \
    -profile test_longread_local,docker \
    --outdir "$OUTDIR" \
    -with-dag "${OUTDIR}/dag.html" \
    -with-report "${OUTDIR}/report.html" \
    -with-trace "${OUTDIR}/trace.txt"

echo ""
echo "=========================================="
echo "Pipeline Execution Complete"
echo "=========================================="
echo ""
echo "Results are in: $OUTDIR"
echo ""
echo "Key outputs to check:"
echo "  - ${OUTDIR}/blaze/              (barcode detection)"
echo "  - ${OUTDIR}/preextract_fastq/   (extracted FASTQ)"
echo "  - ${OUTDIR}/correct_barcodes/    (corrected barcodes)"
echo "  - ${OUTDIR}/vat/                (alignment results)"
echo "  - ${OUTDIR}/barcode_tagged/     (BAM with tags)"
echo "  - ${OUTDIR}/dedup_umitools/     (deduplicated BAM)"
echo "  - ${OUTDIR}/multiqc/            (QC report)"
echo ""
