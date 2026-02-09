#!/bin/bash
# Generate test short-read single-cell RNA-seq data for scVAT pipeline testing
# This script creates minimal paired-end FASTQ files (R1: barcode/UMI, R2: transcript)

set -euo pipefail

echo "=========================================="
echo "Generating Short-Read Test Data"
echo "=========================================="
echo ""

# Create test data directory
TEST_DATA_DIR="test_data/shortread"
mkdir -p "$TEST_DATA_DIR"

# Parameters
NUM_READS=1000
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
import string

# Generate random barcodes
barcodes = set()
while len(barcodes) < $NUM_CELLS:
    bc = ''.join(random.choices('ACGT', k=$BARCODE_LEN))
    barcodes.add(bc)

with open('$WHITELIST', 'w') as f:
    for bc in sorted(barcodes):
        f.write(bc + '\n')

print(f"Generated {len(barcodes)} unique barcodes")
EOF

# Generate some simple transcript sequences (mock sequences)
TRANSCRIPTS=(
    "ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG"
    "GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAG"
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"
)

# Generate R1 and R2 FASTQ files
R1_FILE="$TEST_DATA_DIR/test_R1.fastq"
R2_FILE="$TEST_DATA_DIR/test_R2.fastq"

echo "Generating R1 file (barcode + UMI)..."
echo "Generating R2 file (transcript sequences)..."

python3 << EOF
import random
import gzip

# Read whitelist
with open('$WHITELIST', 'r') as f:
    whitelist = [line.strip() for line in f if line.strip()]

transcripts = [
    "ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG",
    "GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAG",
    "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
    "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
]

# Generate quality scores (Phred+33, all 'F' = quality 38)
def generate_quality(length):
    return 'F' * length

r1_file = open('$R1_FILE', 'w')
r2_file = open('$R2_FILE', 'w')

for i in range($NUM_READS):
    read_id = f"READ_{i:06d}"
    
    # Select random barcode from whitelist
    barcode = random.choice(whitelist)
    
    # Generate random UMI
    umi = ''.join(random.choices('ACGT', k=$UMI_LEN))
    
    # R1: Contains barcode + UMI
    # Format: NNN (random) + barcode + UMI
    r1_seq = 'NNN' + barcode + umi
    r1_qual = generate_quality(len(r1_seq))
    
    # R2: Contains transcript sequence
    transcript = random.choice(transcripts)
    r2_seq = transcript[:50]  # Use first 50bp
    r2_qual = generate_quality(len(r2_seq))
    
    # Write R1
    r1_file.write(f"@{read_id}\n")
    r1_file.write(f"{r1_seq}\n")
    r1_file.write("+\n")
    r1_file.write(f"{r1_qual}\n")
    
    # Write R2
    r2_file.write(f"@{read_id}\n")
    r2_file.write(f"{r2_seq}\n")
    r2_file.write("+\n")
    r2_file.write(f"{r2_qual}\n")

r1_file.close()
r2_file.close()

print(f"Generated $NUM_READS reads")
print(f"R1 file: $R1_FILE")
print(f"R2 file: $R2_FILE")
EOF

# Compress the files
echo ""
echo "Compressing FASTQ files..."
if command -v gzip &> /dev/null; then
    gzip -f "$R1_FILE"
    gzip -f "$R2_FILE"
    R1_FILE="${R1_FILE}.gz"
    R2_FILE="${R2_FILE}.gz"
    echo "✓ Files compressed"
else
    echo "⚠ gzip not found, keeping uncompressed files"
fi

# Create samplesheet
echo ""
echo "Creating samplesheet..."
SAMPLESHEET="$TEST_DATA_DIR/samplesheet_shortread.csv"
# Use relative paths from project root (where Nextflow is launched)
# Files are in test_data/shortread/, so use relative path
R1_REL="test_data/shortread/$(basename "$R1_FILE")"
R2_REL="test_data/shortread/$(basename "$R2_FILE")"
cat > "$SAMPLESHEET" << EOF
sample,fastq_1,fastq_2,cell_count
TEST_SAMPLE,$R1_REL,$R2_REL,$NUM_CELLS
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
echo "    -profile test_shortread_local,docker \\"
echo "    --input $SAMPLESHEET \\"
echo "    --outdir test_output/shortread_test"
echo ""
echo "Or update conf/test_shortread.config to use:"
echo "  input = \"$SAMPLESHEET\""
echo ""
