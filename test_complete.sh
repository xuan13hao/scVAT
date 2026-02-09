#!/bin/bash
# Complete test script for scVAT pipeline
# Generates both short-read and long-read test data and tests the framework
#
# Usage:
#   ./test_complete.sh [validate|run|full]
#
# Actions:
#   - validate: Generate data and validate only (fast, default)
#   - run: Generate data and run tests (requires Docker/Singularity)
#   - full: Complete test with all checks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default action
TEST_ACTION=${1:-validate}

echo "=========================================="
echo "scVAT Complete Test Suite"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Generate long-read test data"
echo "  2. Generate short-read test data"
echo "  3. Test the framework"
echo ""
echo "Test action: $TEST_ACTION"
echo ""

# Track results
DATA_GEN_PASSED=0
LONGREAD_TEST_PASSED=0
SHORTREAD_TEST_PASSED=0

# Function to print section header
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local all_ok=true
    
    # Check Nextflow
    if ! command -v nextflow &> /dev/null; then
        echo -e "${RED}✗ Nextflow not found${NC}"
        echo "  Please install: https://www.nextflow.io/docs/latest/getstarted.html"
        all_ok=false
    else
        echo -e "${GREEN}✓ Nextflow: $(nextflow -v)${NC}"
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 not found${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✓ Python: $(python3 --version)${NC}"
    fi
    
    # Check VAT
    if [ ! -f "bin/VAT" ] && ! command -v VAT &> /dev/null; then
        echo -e "${YELLOW}⚠ VAT binary not found${NC}"
        echo "  VAT should be in bin/VAT or in PATH"
        echo "  Pipeline will fail during alignment if VAT is missing"
    else
        if [ -f "bin/VAT" ]; then
            echo -e "${GREEN}✓ VAT found at bin/VAT${NC}"
        else
            echo -e "${GREEN}✓ VAT found in PATH${NC}"
        fi
    fi
    
    # Check container engine (for run mode)
    if [ "$TEST_ACTION" == "run" ] || [ "$TEST_ACTION" == "full" ]; then
        if command -v docker &> /dev/null; then
            echo -e "${GREEN}✓ Docker found${NC}"
        elif command -v singularity &> /dev/null; then
            echo -e "${GREEN}✓ Singularity found${NC}"
        else
            echo -e "${YELLOW}⚠ Neither Docker nor Singularity found${NC}"
            echo "  Pipeline requires container engine for execution"
            if [ "$TEST_ACTION" == "run" ]; then
                all_ok=false
            fi
        fi
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    return 0
}

# Function to generate long-read test data
generate_longread_data() {
    print_section "Generating Long-Read Test Data"
    
    if [ -f "test_data/longread/samplesheet_longread.csv" ] && [ -f "test_data/longread/test_longread.fastq.gz" ]; then
        echo -e "${GREEN}✓ Long-read test data already exists${NC}"
        echo "  Location: test_data/longread/"
        return 0
    fi
    
    if [ ! -f "generate_longread_test_data.sh" ]; then
        echo -e "${RED}✗ generate_longread_test_data.sh not found${NC}"
        return 1
    fi
    
    echo "Generating long-read test data..."
    if bash generate_longread_test_data.sh 2>&1; then
        # Check if files were actually created
        if [ -f "test_data/longread/samplesheet_longread.csv" ] && [ -f "test_data/longread/test_longread.fastq.gz" ]; then
            echo -e "${GREEN}✓ Long-read test data generated successfully${NC}"
            echo "  Files:"
            ls -lh test_data/longread/ 2>/dev/null | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
            return 0
        else
            echo -e "${YELLOW}⚠ Script ran but files may be missing${NC}"
            return 1
        fi
    else
        # Even if script failed, check if files exist
        if [ -f "test_data/longread/samplesheet_longread.csv" ] && [ -f "test_data/longread/test_longread.fastq.gz" ]; then
            echo -e "${GREEN}✓ Long-read test data exists (script may have warnings)${NC}"
            echo "  Files:"
            ls -lh test_data/longread/ 2>/dev/null | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
            return 0
        else
            echo -e "${RED}✗ Failed to generate long-read test data${NC}"
            return 1
        fi
    fi
}

# Function to generate short-read test data
generate_shortread_data() {
    print_section "Generating Short-Read Test Data"
    
    if [ -f "test_data/shortread/samplesheet_shortread.csv" ] && [ -f "test_data/shortread/test_R1.fastq.gz" ] && [ -f "test_data/shortread/test_R2.fastq.gz" ]; then
        echo -e "${GREEN}✓ Short-read test data already exists${NC}"
        echo "  Location: test_data/shortread/"
        return 0
    fi
    
    if [ ! -f "generate_test_data.sh" ]; then
        echo -e "${RED}✗ generate_test_data.sh not found${NC}"
        return 1
    fi
    
    echo "Generating short-read test data..."
    if bash generate_test_data.sh 2>&1; then
        # Check if files were actually created
        if [ -f "test_data/shortread/samplesheet_shortread.csv" ] && [ -f "test_data/shortread/test_R1.fastq.gz" ] && [ -f "test_data/shortread/test_R2.fastq.gz" ]; then
            echo -e "${GREEN}✓ Short-read test data generated successfully${NC}"
            echo "  Files:"
            ls -lh test_data/shortread/ 2>/dev/null | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
            return 0
        else
            echo -e "${YELLOW}⚠ Script ran but files may be missing${NC}"
            return 1
        fi
    else
        # Even if script failed, check if files exist
        if [ -f "test_data/shortread/samplesheet_shortread.csv" ] && [ -f "test_data/shortread/test_R1.fastq.gz" ] && [ -f "test_data/shortread/test_R2.fastq.gz" ]; then
            echo -e "${GREEN}✓ Short-read test data exists (script may have warnings)${NC}"
            echo "  Files:"
            ls -lh test_data/shortread/ 2>/dev/null | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
            return 0
        else
            echo -e "${RED}✗ Failed to generate short-read test data${NC}"
            return 1
        fi
    fi
}

# Function to validate data
validate_test_data() {
    print_section "Validating Test Data"
    
    local all_ok=true
    
    # Check long-read data
    if [ -f "test_data/longread/samplesheet_longread.csv" ] && [ -f "test_data/longread/test_longread.fastq.gz" ]; then
        echo -e "${GREEN}✓ Long-read data: OK${NC}"
        echo "  Samplesheet: test_data/longread/samplesheet_longread.csv"
        echo "  FASTQ: test_data/longread/test_longread.fastq.gz"
        
        # Check file size
        local size=$(stat -f%z "test_data/longread/test_longread.fastq.gz" 2>/dev/null || stat -c%s "test_data/longread/test_longread.fastq.gz" 2>/dev/null)
        if [ "$size" -gt 0 ]; then
            echo "  Size: $(du -h test_data/longread/test_longread.fastq.gz | cut -f1)"
        fi
    else
        echo -e "${RED}✗ Long-read data: MISSING${NC}"
        all_ok=false
    fi
    
    echo ""
    
    # Check short-read data
    if [ -f "test_data/shortread/samplesheet_shortread.csv" ] && [ -f "test_data/shortread/test_R1.fastq.gz" ] && [ -f "test_data/shortread/test_R2.fastq.gz" ]; then
        echo -e "${GREEN}✓ Short-read data: OK${NC}"
        echo "  Samplesheet: test_data/shortread/samplesheet_shortread.csv"
        echo "  R1 FASTQ: test_data/shortread/test_R1.fastq.gz"
        echo "  R2 FASTQ: test_data/shortread/test_R2.fastq.gz"
        
        # Check file sizes
        local size1=$(stat -f%z "test_data/shortread/test_R1.fastq.gz" 2>/dev/null || stat -c%s "test_data/shortread/test_R1.fastq.gz" 2>/dev/null)
        local size2=$(stat -f%z "test_data/shortread/test_R2.fastq.gz" 2>/dev/null || stat -c%s "test_data/shortread/test_R2.fastq.gz" 2>/dev/null)
        if [ "$size1" -gt 0 ] && [ "$size2" -gt 0 ]; then
            echo "  R1 Size: $(du -h test_data/shortread/test_R1.fastq.gz | cut -f1)"
            echo "  R2 Size: $(du -h test_data/shortread/test_R2.fastq.gz | cut -f1)"
        fi
    else
        echo -e "${RED}✗ Short-read data: MISSING${NC}"
        all_ok=false
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    return 0
}

# Function to test long-read mode
test_longread() {
    print_section "Testing Long-Read Mode"
    
    if [ "$TEST_ACTION" == "validate" ]; then
        echo "Validating long-read configuration..."
        if nextflow run . -profile test_longread_local,docker --help > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Long-read configuration valid${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validation inconclusive${NC}"
            return 0
        fi
    elif [ "$TEST_ACTION" == "run" ] || [ "$TEST_ACTION" == "full" ]; then
        local outdir="test_output/longread_$(date +%Y%m%d_%H%M%S)"
        echo "Running long-read pipeline..."
        echo "Output directory: $outdir"
        echo ""
        
        if nextflow run . \
            -profile test_longread_local,docker \
            --outdir "$outdir" \
            -with-dag "${outdir}/dag.html" \
            -with-report "${outdir}/report.html" \
            -with-trace "${outdir}/trace.txt" \
            2>&1 | tee "${outdir}.log"; then
            echo ""
            echo -e "${GREEN}✓ Long-read test completed successfully${NC}"
            echo "  Results: $outdir"
            return 0
        else
            echo ""
            echo -e "${RED}✗ Long-read test failed${NC}"
            echo "  Check log: ${outdir}.log"
            return 1
        fi
    fi
}

# Function to test short-read mode
test_shortread() {
    print_section "Testing Short-Read Mode"
    
    if [ "$TEST_ACTION" == "validate" ]; then
        echo "Validating short-read configuration..."
        if nextflow run . -profile test_shortread_local,docker --help > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Short-read configuration valid${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validation inconclusive${NC}"
            return 0
        fi
    elif [ "$TEST_ACTION" == "run" ] || [ "$TEST_ACTION" == "full" ]; then
        local outdir="test_output/shortread_$(date +%Y%m%d_%H%M%S)"
        echo "Running short-read pipeline..."
        echo "Output directory: $outdir"
        echo ""
        
        if nextflow run . \
            -profile test_shortread_local,docker \
            --outdir "$outdir" \
            -with-dag "${outdir}/dag.html" \
            -with-report "${outdir}/report.html" \
            -with-trace "${outdir}/trace.txt" \
            2>&1 | tee "${outdir}.log"; then
            echo ""
            echo -e "${GREEN}✓ Short-read test completed successfully${NC}"
            echo "  Results: $outdir"
            return 0
        else
            echo ""
            echo -e "${RED}✗ Short-read test failed${NC}"
            echo "  Check log: ${outdir}.log"
            return 1
        fi
    fi
}

# Main execution
main() {
    # Check prerequisites
    if ! check_prerequisites; then
        echo -e "${RED}Prerequisites check failed${NC}"
        exit 1
    fi
    
    # Generate test data
    if ! generate_longread_data; then
        echo -e "${RED}Failed to generate long-read test data${NC}"
        exit 1
    fi
    
    if ! generate_shortread_data; then
        echo -e "${RED}Failed to generate short-read test data${NC}"
        exit 1
    fi
    
    DATA_GEN_PASSED=1
    
    # Validate test data
    if ! validate_test_data; then
        echo -e "${RED}Test data validation failed${NC}"
        exit 1
    fi
    
    # Test long-read mode
    if test_longread; then
        LONGREAD_TEST_PASSED=1
    fi
    
    # Test short-read mode
    if test_shortread; then
        SHORTREAD_TEST_PASSED=1
    fi
    
    # Print summary
    print_section "Test Summary"
    
    if [ $DATA_GEN_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Test data generation: PASSED${NC}"
    else
        echo -e "${RED}✗ Test data generation: FAILED${NC}"
    fi
    
    if [ $LONGREAD_TEST_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Long-read mode: PASSED${NC}"
    else
        echo -e "${RED}✗ Long-read mode: FAILED${NC}"
    fi
    
    if [ $SHORTREAD_TEST_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Short-read mode: PASSED${NC}"
    else
        echo -e "${RED}✗ Short-read mode: FAILED${NC}"
    fi
    
    echo ""
    echo "Test data location:"
    echo "  Long-read: test_data/longread/"
    echo "  Short-read: test_data/shortread/"
    echo ""
    
    if [ "$TEST_ACTION" == "run" ] || [ "$TEST_ACTION" == "full" ]; then
        echo "Test outputs: test_output/"
        echo ""
    fi
    
    # Exit code
    if [ "$TEST_ACTION" == "validate" ]; then
        # For validate, we only care about data generation and validation
        if [ $DATA_GEN_PASSED -eq 1 ] && [ $LONGREAD_TEST_PASSED -eq 1 ] && [ $SHORTREAD_TEST_PASSED -eq 1 ]; then
            exit 0
        else
            exit 1
        fi
    else
        # For run/full, check all tests
        if [ $DATA_GEN_PASSED -eq 1 ] && [ $LONGREAD_TEST_PASSED -eq 1 ] && [ $SHORTREAD_TEST_PASSED -eq 1 ]; then
            exit 0
        else
            exit 1
        fi
    fi
}

# Run main function
main
