#!/bin/bash
# Test script for scVAT pipeline - testing both long-read and short-read modes
# 
# Usage:
#   ./test_longread_shortread.sh [long_read|short_read|both]
#
# This script tests the scVAT pipeline with minimal test data

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default test mode
TEST_MODE=${1:-both}

echo "=========================================="
echo "scVAT Pipeline Test Script"
echo "=========================================="
echo ""
echo "Test mode: $TEST_MODE"
echo ""

# Check if Nextflow is installed
if ! command -v nextflow &> /dev/null; then
    echo -e "${RED}✗ Nextflow is not installed${NC}"
    echo "  Please install Nextflow: https://www.nextflow.io/docs/latest/getstarted.html"
    exit 1
fi
echo -e "${GREEN}✓ Nextflow found${NC}"

# Check if VAT binary exists
if [ ! -f "bin/VAT" ] && ! command -v VAT &> /dev/null; then
    echo -e "${YELLOW}⚠ VAT binary not found${NC}"
    echo "  VAT should be in bin/VAT or in PATH"
    echo "  The pipeline will fail if VAT is not available"
else
    echo -e "${GREEN}✓ VAT binary found${NC}"
fi

# Create test output directory
OUTDIR="test_output"
mkdir -p "$OUTDIR"

# Function to test long-read mode
test_longread() {
    echo ""
    echo "=========================================="
    echo "Testing LONG-READ mode"
    echo "=========================================="
    echo ""
    
    # Check if test config exists
    if [ ! -f "conf/test_longread.config" ]; then
        echo -e "${RED}✗ Test config not found: conf/test_longread.config${NC}"
        return 1
    fi
    
    echo "Running long-read test..."
    echo "Command: nextflow run . -profile test_longread,docker --outdir ${OUTDIR}/longread_test"
    echo ""
    
    # Run with dry-run first to check syntax
    if nextflow run . -profile test_longread,docker --outdir "${OUTDIR}/longread_test" -with-dag "${OUTDIR}/longread_test/dag.html" -with-report "${OUTDIR}/longread_test/report.html" 2>&1 | tee "${OUTDIR}/longread_test.log"; then
        echo ""
        echo -e "${GREEN}✓ Long-read test completed${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Long-read test failed${NC}"
        return 1
    fi
}

# Function to test short-read mode
test_shortread() {
    echo ""
    echo "=========================================="
    echo "Testing SHORT-READ mode"
    echo "=========================================="
    echo ""
    
    # Check if test config exists
    if [ ! -f "conf/test_shortread.config" ]; then
        echo -e "${RED}✗ Test config not found: conf/test_shortread.config${NC}"
        return 1
    fi
    
    echo "Running short-read test..."
    echo "Command: nextflow run . -profile test_shortread,docker --outdir ${OUTDIR}/shortread_test"
    echo ""
    
    # Run with dry-run first to check syntax
    if nextflow run . -profile test_shortread,docker --outdir "${OUTDIR}/shortread_test" -with-dag "${OUTDIR}/shortread_test/dag.html" -with-report "${OUTDIR}/shortread_test/report.html" 2>&1 | tee "${OUTDIR}/shortread_test.log"; then
        echo ""
        echo -e "${GREEN}✓ Short-read test completed${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Short-read test failed${NC}"
        return 1
    fi
}

# Run tests based on mode
LONGREAD_PASSED=0
SHORTREAD_PASSED=0

if [ "$TEST_MODE" == "long_read" ] || [ "$TEST_MODE" == "both" ]; then
    if test_longread; then
        LONGREAD_PASSED=1
    fi
fi

if [ "$TEST_MODE" == "short_read" ] || [ "$TEST_MODE" == "both" ]; then
    if test_shortread; then
        SHORTREAD_PASSED=1
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""

if [ "$TEST_MODE" == "long_read" ] || [ "$TEST_MODE" == "both" ]; then
    if [ $LONGREAD_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Long-read mode: PASSED${NC}"
    else
        echo -e "${RED}✗ Long-read mode: FAILED${NC}"
    fi
fi

if [ "$TEST_MODE" == "short_read" ] || [ "$TEST_MODE" == "both" ]; then
    if [ $SHORTREAD_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Short-read mode: PASSED${NC}"
    else
        echo -e "${RED}✗ Short-read mode: FAILED${NC}"
    fi
fi

echo ""
echo "Test outputs are in: $OUTDIR/"
echo ""

# Exit with error if any test failed
if [ "$TEST_MODE" == "both" ]; then
    if [ $LONGREAD_PASSED -eq 1 ] && [ $SHORTREAD_PASSED -eq 1 ]; then
        exit 0
    else
        exit 1
    fi
elif [ "$TEST_MODE" == "long_read" ]; then
    exit $((1 - LONGREAD_PASSED))
elif [ "$TEST_MODE" == "short_read" ]; then
    exit $((1 - SHORTREAD_PASSED))
fi
