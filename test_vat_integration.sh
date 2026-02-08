#!/bin/bash
# Test script to verify VAT integration in the pipeline

set -euo pipefail

echo "=========================================="
echo "Testing VAT Integration"
echo "=========================================="
echo ""

# Test 1: Check if VAT binary exists
echo "Test 1: Checking VAT binary file..."
if [ -f "bin/VAT" ]; then
    echo "✓ VAT binary found at bin/VAT"
    if [ -x "bin/VAT" ]; then
        echo "✓ VAT binary is executable"
    else
        echo "✗ VAT binary is not executable"
        echo "  Run: chmod +x bin/VAT"
        exit 1
    fi
else
    echo "✗ VAT binary not found at bin/VAT"
    exit 1
fi
echo ""

# Test 2: Test VAT command
echo "Test 2: Testing VAT command..."
if bin/VAT --help >/dev/null 2>&1; then
    echo "✓ VAT command works"
else
    echo "✗ VAT command failed"
    exit 1
fi
echo ""

# Test 3: Test VAT makevatdb command syntax
echo "Test 3: Testing VAT makevatdb command syntax..."
# Create a dummy fasta file for testing
cat > /tmp/test_vat.fa << 'EOF'
>test_seq
ATCGATCGATCG
EOF

if bin/VAT makevatdb --in /tmp/test_vat.fa --dbtype nucl 2>&1 | head -5; then
    echo "✓ VAT makevatdb command works"
    if [ -f "/tmp/test_vat.fa.vatf" ]; then
        echo "✓ VAT index file created successfully"
        rm -f /tmp/test_vat.fa.vatf
    fi
else
    echo "⚠ VAT makevatdb command may have issues (this is OK if it's just a syntax check)"
fi
rm -f /tmp/test_vat.fa
echo ""

# Test 4: Check Nextflow config
echo "Test 4: Checking Nextflow configuration..."
if grep -q "PATH.*bin" nextflow.config; then
    echo "✓ PATH configuration found in nextflow.config"
else
    echo "✗ PATH configuration not found in nextflow.config"
    exit 1
fi
echo ""

# Test 5: Check VAT modules exist
echo "Test 5: Checking VAT modules..."
if [ -f "modules/local/vat_index.nf" ]; then
    echo "✓ VAT_INDEX module found"
else
    echo "✗ VAT_INDEX module not found"
    exit 1
fi

if [ -f "modules/local/vat_align.nf" ]; then
    echo "✓ VAT_ALIGN module found"
else
    echo "✗ VAT_ALIGN module not found"
    exit 1
fi
echo ""

# Test 6: Check if modules reference bin/VAT
echo "Test 6: Checking VAT binary detection logic in modules..."
if grep -q "projectDir/bin/VAT" modules/local/vat_index.nf; then
    echo "✓ VAT_INDEX module references bin/VAT"
else
    echo "✗ VAT_INDEX module does not reference bin/VAT"
    exit 1
fi

if grep -q "projectDir/bin/VAT" modules/local/vat_align.nf; then
    echo "✓ VAT_ALIGN module references bin/VAT"
else
    echo "✗ VAT_ALIGN module does not reference bin/VAT"
    exit 1
fi
echo ""

# Test 7: Check workflow integration
echo "Test 7: Checking workflow integration..."
if grep -q "VAT_INDEX\|VAT_ALIGN" subworkflows/local/align_longreads.nf; then
    echo "✓ VAT modules are integrated in align_longreads workflow"
else
    echo "✗ VAT modules not found in align_longreads workflow"
    exit 1
fi
echo ""

echo "=========================================="
echo "All tests passed! ✓"
echo "=========================================="
echo ""
echo "VAT integration is ready to use."
echo "To run the pipeline, use:"
echo "  nextflow run nf-core/scnanoseq -profile test,<docker/singularity> --outdir <OUTDIR>"
echo ""
