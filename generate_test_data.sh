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
NUM_CELLS=5  # Reduced to 5 cells so each has ~200 reads (better for UMI-tools whitelist detection)
BARCODE_LEN=16
UMI_LEN=12

echo "Parameters:"
echo "  Number of reads: $NUM_READS"
echo "  Number of cells: $NUM_CELLS"
echo "  Barcode length: $BARCODE_LEN"
echo "  UMI length: $UMI_LEN"
echo ""

# Generate whitelist of cell barcodes from 10x Genomics whitelist
echo "Sampling cell barcodes from 10x Genomics whitelist..."
WHITELIST="$TEST_DATA_DIR/whitelist.txt"
TENX_WHITELIST="assets/whitelist/3M-february-2018.zip"

if [ ! -f "$TENX_WHITELIST" ]; then
    echo "ERROR: 10x whitelist not found at $TENX_WHITELIST"
    exit 1
fi

python3 << EOF
import random
import zipfile

# Read 10x whitelist
with zipfile.ZipFile('$TENX_WHITELIST', 'r') as z:
    with z.open('3M-february-2018.txt') as f:
        tenx_barcodes = [line.decode().strip() for line in f if line.strip()]

# Sample random barcodes from the 10x whitelist
sampled_barcodes = random.sample(tenx_barcodes, $NUM_CELLS)

# Save to whitelist file
with open('$WHITELIST', 'w') as f:
    for bc in sorted(sampled_barcodes):
        f.write(bc + '\n')

print(f"Sampled {len(sampled_barcodes)} barcodes from 10x Genomics whitelist")
EOF

# Download reference genome for extracting real sequences
echo "Downloading chr21 reference..."
CHR21_FA="$TEST_DATA_DIR/chr21_ref.fa"
if [ ! -f "$CHR21_FA" ]; then
    wget -q -O "$CHR21_FA" "https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.fa"
    echo "✓ Reference downloaded"
else
    echo "✓ Reference already exists"
fi

# Extract real transcript sequences from chr21.fa
echo "Extracting real sequences from chr21 reference..."

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

# Extract real sequences from chr21.fa
print("Extracting sequences from chr21 reference...")
with open('$CHR21_FA', 'r') as f:
    # Skip header line
    _ = f.readline()
    # Read entire sequence (strip newlines)
    chr21_seq = ''.join(line.strip() for line in f)

# Extract multiple random 100bp sequences from chr21
transcripts = []
for _ in range(20):
    start_pos = random.randint(0, len(chr21_seq) - 100)
    seq = chr21_seq[start_pos:start_pos+100]
    # Only use sequences without N's
    if 'N' not in seq and len(seq) == 100:
        transcripts.append(seq)

print(f"Extracted {len(transcripts)} sequences from chr21 reference")

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

    # Generate random prefix (3bp random nucleotides, not literal "NNN")
    random_prefix = ''.join(random.choices('ACGT', k=3))

    # R1: Contains random prefix + barcode + UMI
    # Format: random 3bp + barcode + UMI (matching pattern NNNCCCCCCCCCCCCCCNNNNNNNNNNNN)
    r1_seq = random_prefix + barcode + umi
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
