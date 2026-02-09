#!/bin/bash
# Generate test long-read single-cell RNA-seq data for scVAT pipeline testing
# This script creates minimal FASTQ files simulating Oxford Nanopore long reads

set -euo pipefail

echo "=========================================="
echo "Generating Long-Read Test Data"
echo "=========================================="
echo ""

# Create test data directory
TEST_DATA_DIR="test_data/longread"
mkdir -p "$TEST_DATA_DIR"

# Parameters
NUM_READS=500
NUM_CELLS=10
BARCODE_LEN=16
UMI_LEN=12

echo "Parameters:"
echo "  Number of reads: $NUM_READS"
echo "  Number of cells: $NUM_CELLS"
echo "  Barcode length: $BARCODE_LEN"
echo "  UMI length: $UMI_LEN"
echo ""

# Generate whitelist of cell barcodes
echo "Generating cell barcode whitelist..."
WHITELIST="$TEST_DATA_DIR/whitelist.txt"
python3 << EOF
import random

barcodes = set()
while len(barcodes) < $NUM_CELLS:
    bc = ''.join(random.choices('ACGT', k=$BARCODE_LEN))
    barcodes.add(bc)

with open('$WHITELIST', 'w') as f:
    for bc in sorted(barcodes):
        f.write(bc + '\n')

print(f"Generated {len(barcodes)} unique barcodes")
EOF

# Generate long-read FASTQ file
FASTQ_FILE="$TEST_DATA_DIR/test_longread.fastq"

echo "Generating long-read FASTQ file..."
python3 << EOF
import random
import gzip

# Read whitelist
with open('$WHITELIST', 'r') as f:
    whitelist = [line.strip() for line in f if line.strip()]

# Generate some transcript sequences (longer for long-reads)
transcripts = [
    "ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG",
    "GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAG",
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
]

def generate_quality(length):
    # For long-reads, use a mix of quality scores (simulating Nanopore)
    return ''.join(random.choices('FGHIJKLMNOPQRSTUVWXYZ', k=length))

fq_file = open('$FASTQ_FILE', 'w')

for i in range($NUM_READS):
    read_id = f"READ_{i:06d}"
    
    # Select random barcode from whitelist
    barcode = random.choice(whitelist)
    
    # Generate random UMI
    umi = ''.join(random.choices('ACGT', k=$UMI_LEN))
    
    # For long-reads, the barcode and UMI are embedded in the read sequence
    # Format: NNN (primer) + barcode + UMI + polyT + transcript
    primer = 'NNN'
    polyT = 'T' * 20
    transcript = random.choice(transcripts)
    
    # Full read sequence
    read_seq = primer + barcode + umi + polyT + transcript
    read_qual = generate_quality(len(read_seq))
    
    # Write FASTQ entry
    fq_file.write(f"@{read_id}\n")
    fq_file.write(f"{read_seq}\n")
    fq_file.write("+\n")
    fq_file.write(f"{read_qual}\n")

fq_file.close()

print(f"Generated $NUM_READS long reads")
print(f"FASTQ file: $FASTQ_FILE")
EOF

# Compress the file
echo ""
echo "Compressing FASTQ file..."
if command -v gzip &> /dev/null; then
    gzip -f "$FASTQ_FILE"
    FASTQ_FILE="${FASTQ_FILE}.gz"
    echo "✓ File compressed"
else
    echo "⚠ gzip not found, keeping uncompressed file"
fi

# Create samplesheet
echo ""
echo "Creating samplesheet..."
SAMPLESHEET="$TEST_DATA_DIR/samplesheet_longread.csv"
cat > "$SAMPLESHEET" << EOF
sample,fastq,cell_count
TEST_SAMPLE,$(pwd)/$FASTQ_FILE,$NUM_CELLS
EOF

echo "✓ Samplesheet created: $SAMPLESHEET"

# Display file sizes
echo ""
echo "=========================================="
echo "Generated Files"
echo "=========================================="
echo ""
ls -lh "$TEST_DATA_DIR"/*.{fastq.gz,fastq,txt,csv} 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Display samplesheet content
echo "Samplesheet content:"
cat "$SAMPLESHEET"
echo ""

echo "=========================================="
echo "Test Data Generation Complete!"
echo "=========================================="
echo ""
echo "To test the pipeline with this data, run:"
echo ""
echo "  nextflow run . \\"
echo "    -profile test_longread_local,docker \\"
echo "    --input $SAMPLESHEET \\"
echo "    --outdir test_output/longread_test"
echo ""
