#!/bin/bash
# Test script for short-read mode only
# This script tests the short-read single-cell RNA-seq workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "=========================================="
echo "scVAT Short-Read Mode Test"
echo "=========================================="
echo ""

# Check if test data exists
if [ ! -f "test_data/shortread/samplesheet_shortread.csv" ]; then
    echo -e "${YELLOW}⚠ Short-read test data not found${NC}"
    echo "Generating test data..."
    bash generate_test_data.sh
    echo ""
fi

# Auto-detect container engine
CONTAINER_PROFILE=""
if command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
    CONTAINER_PROFILE="docker"
    echo -e "${GREEN}✓ Using Docker${NC}"
elif command -v apptainer &> /dev/null; then
    CONTAINER_PROFILE="apptainer"
    echo -e "${GREEN}✓ Using Apptainer${NC}"
elif command -v singularity &> /dev/null; then
    CONTAINER_PROFILE="singularity"
    echo -e "${GREEN}✓ Using Singularity${NC}"
else
    CONTAINER_PROFILE="conda"
    echo -e "${YELLOW}⚠ No container engine found, using conda${NC}"
fi

echo ""
echo "=========================================="
echo "Running Short-Read Pipeline"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Input type: short_read"
echo "  Samplesheet: test_data/shortread/samplesheet_shortread.csv"
echo "  Container: $CONTAINER_PROFILE"
echo "  Output: test_output/shortread_test"
echo ""

# Check if reference files exist, if not use URLs
GENOME_FASTA=""
GTF=""

if [ -f "test_data/reference/chr21.fa" ]; then
    GENOME_FASTA="test_data/reference/chr21.fa"
    echo -e "${GREEN}✓ Using local genome reference${NC}"
else
    GENOME_FASTA="https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.fa"
    echo -e "${YELLOW}⚠ Using remote genome reference${NC}"
fi

if [ -f "test_data/reference/chr21.gtf" ]; then
    GTF="test_data/reference/chr21.gtf"
    echo -e "${GREEN}✓ Using local GTF reference${NC}"
else
    GTF="https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.gtf"
    echo -e "${YELLOW}⚠ Using remote GTF reference${NC}"
fi

echo ""

# Run the pipeline
nextflow run . \
    -profile test_shortread_local,$CONTAINER_PROFILE \
    --input_type short_read \
    --input test_data/shortread/samplesheet_shortread.csv \
    --outdir test_output/shortread_test \
    --genome_fasta "$GENOME_FASTA" \
    --gtf "$GTF" \
    --barcode_length 16 \
    --umi_length 12 \
    --quantifier isoquant \
    -resume

echo ""
echo "=========================================="
echo "Test Complete!"
echo "=========================================="
echo ""
echo "Results are in: test_output/shortread_test"
echo ""
