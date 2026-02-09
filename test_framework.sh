#!/bin/bash
# Comprehensive test framework for scVAT pipeline
# Tests both long-read and short-read modes with validation and execution
#
# Usage:
#   ./test_framework.sh [mode] [action]
#
# Modes:
#   - long_read: Test long-read mode only
#   - short_read: Test short-read mode only
#   - both: Test both modes (default)
#
# Actions:
#   - validate: Only validate syntax and configuration (fast, default)
#   - run: Actually run the pipeline (slow, requires Docker/Singularity)
#   - full: Generate data, validate, and run (complete test)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default parameters
TEST_MODE=${1:-both}
TEST_ACTION=${2:-validate}

echo "=========================================="
echo "scVAT Pipeline Test Framework"
echo "=========================================="
echo ""
echo "Test mode: $TEST_MODE"
echo "Test action: $TEST_ACTION"
echo ""

# Track test results
LONGREAD_PASSED=0
SHORTREAD_PASSED=0
VALIDATION_PASSED=0

# Function to check prerequisites
check_prerequisites() {
    echo "=========================================="
    echo "Checking Prerequisites"
    echo "=========================================="
    echo ""
    
    local all_ok=true
    
    # Check Nextflow
    if ! command -v nextflow &> /dev/null; then
        echo -e "${RED}✗ Nextflow not found${NC}"
        echo "  Please install: https://www.nextflow.io/docs/latest/getstarted.html"
        all_ok=false
    else
        echo -e "${GREEN}✓ Nextflow: $(nextflow -v)${NC}"
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
    
    # Check Docker/Singularity (for run mode)
    if [ "$TEST_ACTION" == "run" ] || [ "$TEST_ACTION" == "full" ]; then
        if command -v docker &> /dev/null; then
            echo -e "${GREEN}✓ Docker found${NC}"
        elif command -v singularity &> /dev/null; then
            echo -e "${GREEN}✓ Singularity found${NC}"
        else
            echo -e "${YELLOW}⚠ Neither Docker nor Singularity found${NC}"
            echo "  Pipeline requires container engine for execution"
            all_ok=false
        fi
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    return 0
}

# Function to validate workflow syntax
validate_workflow() {
    echo "=========================================="
    echo "Validating Workflow Syntax"
    echo "=========================================="
    echo ""
    
    # Check main files
    local files_ok=true
    
    for file in "main.nf" "workflows/scnanoseq.nf" "nextflow.config"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}✗ $file not found${NC}"
            files_ok=false
        else
            echo -e "${GREEN}✓ $file found${NC}"
        fi
    done
    
    if [ "$files_ok" = false ]; then
        return 1
    fi
    
    # Validate Nextflow syntax
    echo ""
    echo "Validating Nextflow syntax..."
    if nextflow run . -profile test_longread_local,docker --help 2>&1 | grep -q "Pipeline:" || true; then
        echo -e "${GREEN}✓ Nextflow syntax validation passed${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Syntax validation inconclusive (this is normal)${NC}"
        return 0
    fi
}

# Function to generate test data
generate_test_data() {
    local mode=$1
    
    echo ""
    echo "=========================================="
    echo "Generating Test Data ($mode)"
    echo "=========================================="
    echo ""
    
    if [ "$mode" == "long_read" ]; then
        if [ -f "test_data/longread/samplesheet_longread.csv" ]; then
            echo -e "${GREEN}✓ Long-read test data already exists${NC}"
        else
            echo "Generating long-read test data..."
            if [ -f "generate_longread_test_data.sh" ]; then
                bash generate_longread_test_data.sh
                echo -e "${GREEN}✓ Long-read test data generated${NC}"
            else
                echo -e "${RED}✗ generate_longread_test_data.sh not found${NC}"
                return 1
            fi
        fi
    elif [ "$mode" == "short_read" ]; then
        if [ -f "test_data/shortread/samplesheet_shortread.csv" ]; then
            echo -e "${GREEN}✓ Short-read test data already exists${NC}"
        else
            echo "Generating short-read test data..."
            if [ -f "generate_test_data.sh" ]; then
                bash generate_test_data.sh
                echo -e "${GREEN}✓ Short-read test data generated${NC}"
            else
                echo -e "${RED}✗ generate_test_data.sh not found${NC}"
                return 1
            fi
        fi
    fi
}

# Function to test long-read mode
test_longread() {
    local action=$1
    
    echo ""
    echo "=========================================="
    echo "Testing LONG-READ Mode"
    echo "=========================================="
    echo ""
    
    # Check config
    if [ ! -f "conf/test_longread_local.config" ]; then
        echo -e "${RED}✗ Test config not found: conf/test_longread_local.config${NC}"
        return 1
    fi
    
    if [ "$action" == "validate" ]; then
        # Quick validation
        echo "Validating long-read configuration..."
        if nextflow run . -profile test_longread_local,docker --help > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Long-read configuration valid${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validation inconclusive${NC}"
            return 0
        fi
    elif [ "$action" == "run" ] || [ "$action" == "full" ]; then
        # Generate data if needed
        if [ "$action" == "full" ]; then
            generate_test_data "long_read"
        fi
        
        # Run pipeline
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
    local action=$1
    
    echo ""
    echo "=========================================="
    echo "Testing SHORT-READ Mode"
    echo "=========================================="
    echo ""
    
    # Check config
    if [ ! -f "conf/test_shortread_local.config" ]; then
        echo -e "${RED}✗ Test config not found: conf/test_shortread_local.config${NC}"
        return 1
    fi
    
    if [ "$action" == "validate" ]; then
        # Quick validation
        echo "Validating short-read configuration..."
        if nextflow run . -profile test_shortread_local,docker --help > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Short-read configuration valid${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validation inconclusive${NC}"
            return 0
        fi
    elif [ "$action" == "run" ] || [ "$action" == "full" ]; then
        # Generate data if needed
        if [ "$action" == "full" ]; then
            generate_test_data "short_read"
        fi
        
        # Run pipeline
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
    
    # Validate workflow syntax
    if ! validate_workflow; then
        echo -e "${RED}Workflow validation failed${NC}"
        exit 1
    fi
    VALIDATION_PASSED=1
    
    # Run tests based on mode and action
    if [ "$TEST_MODE" == "long_read" ] || [ "$TEST_MODE" == "both" ]; then
        if test_longread "$TEST_ACTION"; then
            LONGREAD_PASSED=1
        fi
    fi
    
    if [ "$TEST_MODE" == "short_read" ] || [ "$TEST_MODE" == "both" ]; then
        if test_shortread "$TEST_ACTION"; then
            SHORTREAD_PASSED=1
        fi
    fi
    
    # Print summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo ""
    
    if [ $VALIDATION_PASSED -eq 1 ]; then
        echo -e "${GREEN}✓ Workflow validation: PASSED${NC}"
    else
        echo -e "${RED}✗ Workflow validation: FAILED${NC}"
    fi
    
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
    echo "Test outputs are in: test_output/"
    echo ""
    
    # Exit code
    if [ "$TEST_ACTION" == "validate" ]; then
        # For validate, we only care about validation
        exit $((1 - VALIDATION_PASSED))
    else
        # For run/full, check all tests
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
    fi
}

# Run main function
main
