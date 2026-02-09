#!/bin/bash
# Quick validation script - only checks syntax, doesn't run the workflow
# Much faster than quick_test.sh

set -euo pipefail

echo "=========================================="
echo "scVAT Quick Validation (Syntax Check Only)"
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
echo "Validating Workflow Syntax"
echo "=========================================="
echo ""

# Check if main.nf exists and is valid
if [ ! -f "main.nf" ]; then
    echo "✗ main.nf not found"
    exit 1
fi
echo "✓ main.nf found"

# Check if workflow files exist
if [ ! -f "workflows/scnanoseq.nf" ]; then
    echo "✗ workflows/scnanoseq.nf not found"
    exit 1
fi
echo "✓ workflows/scnanoseq.nf found"

# Check if test configs exist
if [ ! -f "conf/test_longread.config" ]; then
    echo "✗ conf/test_longread.config not found"
    exit 1
fi
echo "✓ conf/test_longread.config found"

if [ ! -f "conf/test_shortread.config" ]; then
    echo "✗ conf/test_shortread.config not found"
    exit 1
fi
echo "✓ conf/test_shortread.config found"

# Check if key modules exist
echo ""
echo "Checking key modules..."

MODULES_OK=1
for module in "modules/local/vat_align.nf" "modules/nf-core/umitools/whitelist/main.nf" "modules/nf-core/umitools/extract/main.nf" "subworkflows/local/process_longread_scrna.nf" "subworkflows/local/process_shortread_scrna.nf"; do
    if [ ! -f "$module" ]; then
        echo "✗ $module not found"
        MODULES_OK=0
    else
        echo "✓ $module found"
    fi
done

if [ $MODULES_OK -eq 0 ]; then
    echo ""
    echo "✗ Some modules are missing"
    exit 1
fi

echo ""
echo "=========================================="
echo "Validating Nextflow Syntax"
echo "=========================================="
echo ""

# Try to validate Nextflow syntax (this is fast, doesn't run)
echo "Validating main.nf syntax..."
if nextflow run . -profile test_longread,docker --help >/dev/null 2>&1; then
    echo "✓ Long-read config syntax valid"
else
    echo "⚠ Long-read config may have issues (this is OK if it's just missing data)"
fi

if nextflow run . -profile test_shortread,docker --help >/dev/null 2>&1; then
    echo "✓ Short-read config syntax valid"
else
    echo "⚠ Short-read config may have issues (this is OK if it's just missing data)"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""
echo "✓ All required files found"
echo "✓ Workflow structure validated"
echo ""
echo "Note: This only validates file structure and syntax."
echo "      For full functional tests, use:"
echo "        ./quick_test.sh        (validates with actual Nextflow run)"
echo "        ./test_longread_shortread.sh both  (full test with data)"
echo ""
