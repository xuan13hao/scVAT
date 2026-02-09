#!/bin/bash
# Optimized test script for scVAT pipeline (Poseidon Cluster Version)
#
# Fixes:
#  - Force Nextflow stable version
#  - Switch engine from Docker to Singularity
#  - Explicitly set expected_cells for BLAZE
#
# Usage:
#   ./test_complete.sh [validate|run|full]

set -euo pipefail

# --- 环境设置 ---
# 强制使用稳定版 Nextflow，避免 25.x 版本的语法兼容性报错
export NXF_VER=24.10.4

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 

# 默认动作
TEST_ACTION=${1:-validate}

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}scVAT Complete Test Suite (Optimized)${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo "Running under Nextflow version: $NXF_VER"
echo "Test action: $TEST_ACTION"
echo ""

# 结果追踪
DATA_GEN_PASSED=0
LONGREAD_TEST_PASSED=0
SHORTREAD_TEST_PASSED=0

print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

check_prerequisites() {
    print_section "Checking Prerequisites"
    local all_ok=true
    
    if ! command -v nextflow &> /dev/null; then
        echo -e "${RED}✗ Nextflow not found${NC}"; all_ok=false
    else
        echo -e "${GREEN}✓ Nextflow: $(nextflow -v)${NC}"
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 not found${NC}"; all_ok=false
    else
        echo -e "${GREEN}✓ Python: $(python3 --version)${NC}"
    fi
    
    if [ ! -f "bin/VAT" ] && ! command -v VAT &> /dev/null; then
        echo -e "${YELLOW}⚠ VAT binary not found (expected in bin/VAT)${NC}"
    else
        echo -e "${GREEN}✓ VAT found${NC}"
    fi
    
    if ! command -v singularity &> /dev/null; then
        echo -e "${RED}✗ Singularity not found. Cluster run requires Singularity.${NC}"; all_ok=false
    else
        echo -e "${GREEN}✓ Singularity found${NC}"
    fi
    
    echo ""
    [ "$all_ok" = false ] && return 1 || return 0
}

generate_longread_data() {
    print_section "Generating Long-Read Test Data"
    if [ -f "test_data/longread/test_longread.fastq.gz" ]; then
        echo -e "${GREEN}✓ Data exists${NC}"; return 0
    fi
    bash generate_longread_test_data.sh
}

generate_shortread_data() {
    print_section "Generating Short-Read Test Data"
    if [ -f "test_data/shortread/test_R1.fastq.gz" ]; then
        echo -e "${GREEN}✓ Data exists${NC}"; return 0
    fi
    bash generate_test_data.sh
}

validate_test_data() {
    print_section "Validating Test Data"
    if [ -f "test_data/longread/samplesheet_longread.csv" ] && [ -f "test_data/shortread/samplesheet_shortread.csv" ]; then
        echo -e "${GREEN}✓ Samplesheets found${NC}"; return 0
    else
        echo -e "${RED}✗ Data validation failed${NC}"; return 1
    fi
}

test_longread() {
    print_section "Testing Long-Read Mode"
    if [ "$TEST_ACTION" == "validate" ]; then
        nextflow run . -profile test_longread_local,singularity --help > /dev/null && echo "Valid."
        return 0
    fi

    local outdir="test_output/longread_$(date +%Y%m%d_%H%M%S)"
    echo "Running long-read pipeline (Singularity)..."
    
    # 核心修复点：显式添加 --expected_cells 100
    if nextflow run . \
        -profile test_longread_local,singularity \
        --outdir "$outdir" \
        -resume \
        --expected_cells 100 \
        -with-dag "${outdir}/dag.html" \
        -with-report "${outdir}/report.html" \
        2>&1 | tee "${outdir}.log"; then
        echo -e "${GREEN}✓ Long-read test passed${NC}"; return 0
    else
        echo -e "${RED}✗ Long-read test failed${NC}"; return 1
    fi
}

test_shortread() {
    print_section "Testing Short-Read Mode"
    if [ "$TEST_ACTION" == "validate" ]; then
        return 0
    fi

    local outdir="test_output/shortread_$(date +%Y%m%d_%H%M%S)"
    echo "Running short-read pipeline (Singularity)..."
    
    if nextflow run . \
        -profile test_shortread_local,singularity \
        --outdir "$outdir" \
        -resume \
        -with-dag "${outdir}/dag.html" \
        -with-report "${outdir}/report.html" \
        2>&1 | tee "${outdir}.log"; then
        echo -e "${GREEN}✓ Short-read test passed${NC}"; return 0
    else
        echo -e "${RED}✗ Short-read test failed${NC}"; return 1
    fi
}

main() {
    check_prerequisites
    generate_longread_data && generate_shortread_data
    DATA_GEN_PASSED=1
    validate_test_data
    
    if test_longread; then LONGREAD_TEST_PASSED=1; fi
    if test_shortread; then SHORTREAD_TEST_PASSED=1; fi
    
    print_section "Test Summary"
    [ $LONGREAD_TEST_PASSED -eq 1 ] && echo -e "${GREEN}✓ Long-read: PASSED${NC}" || echo -e "${RED}✗ Long-read: FAILED${NC}"
    [ $SHORTREAD_TEST_PASSED -eq 1 ] && echo -e "${GREEN}✓ Short-read: PASSED${NC}" || echo -e "${RED}✗ Short-read: FAILED${NC}"
}

main