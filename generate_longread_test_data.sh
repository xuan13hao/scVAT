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
NUM_READS=5000  # Increased to 5000 for better BAM splitting and quantification
NUM_CELLS=10
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

# Generate long-read FASTQ file
FASTQ_FILE="$TEST_DATA_DIR/test_longread.fastq"

echo "Generating long-read FASTQ file..."
echo "Extracting real sequences from chr21 reference..."
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

# Extract multiple random sequences from chr21 (longer for long-reads: 200-500bp)
transcripts = []
for _ in range(30):
    read_length = random.randint(200, 500)
    start_pos = random.randint(0, len(chr21_seq) - read_length)
    seq = chr21_seq[start_pos:start_pos+read_length]
    # Only use sequences without N's
    if 'N' not in seq and len(seq) == read_length:
        transcripts.append(seq)

print(f"Extracted {len(transcripts)} transcript sequences from chr21 reference")

def generate_quality(length, min_qual='P'):
    # For long-reads, use quality scores >= 15 (P in Phred+33) for barcode/UMI regions
    # BLAZE requires Q>=15 for barcode bases
    # Use higher quality for barcode/UMI, lower for transcript
    high_qual = ''.join(random.choices('PQRSTUVWXYZ', k=length))
    return high_qual

fq_file = open('$FASTQ_FILE', 'w')

for i in range($NUM_READS):
    read_id = f"READ_{i:06d}"

    # Select random barcode from whitelist
    barcode = random.choice(whitelist)

    # Generate random UMI
    umi = ''.join(random.choices('ACGT', k=$UMI_LEN))

    # For long-reads, the barcode and UMI are embedded in the read sequence
    # Format for 10X 3v3: [random prefix] + TSO adapter + barcode (16bp) + UMI (12bp) + polyT (10-20bp) + transcript
    # BLAZE expects to find polyT and TSO adapter sequences to identify barcode position
    # TSO adapter for 10x Genomics v3: CTACACGACGCTCTTCCGATCT
    tso_adapter = "CTACACGACGCTCTTCCGATCT"

    # Add a short random prefix (5-15bp) before TSO adapter to simulate natural reads
    random_prefix = ''.join(random.choices('ACGT', k=random.randint(5, 15)))

    # Use longer polyT to help BLAZE detect it (minimum 10bp, use 15bp for better detection)
    polyT = 'T' * 15
    transcript = random.choice(transcripts)

    # Full read sequence: random_prefix + TSO adapter + barcode + UMI + polyT + transcript
    # BLAZE will search for TSO adapter and polyT patterns to locate and extract barcode
    read_seq = random_prefix + tso_adapter + barcode + umi + polyT + transcript
    
    # Generate quality scores: high quality for all regions (required by BLAZE: Q>=15 for barcode/UMI)
    # Phred+33: P=15, Q=16, R=17, S=18, T=19, U=20, V=21, W=22, X=23, Y=24, Z=25
    prefix_qual = ''.join(random.choices('PQRSTUVWXYZ', k=len(random_prefix)))
    adapter_qual = ''.join(random.choices('PQRSTUVWXYZ', k=len(tso_adapter)))
    bc_umi_qual = ''.join(random.choices('PQRSTUVWXYZ', k=len(barcode) + len(umi)))
    polyT_qual = ''.join(random.choices('PQRSTUVWXYZ', k=len(polyT)))
    transcript_qual = ''.join(random.choices('FGHIJKLMNOPQRSTUVWXYZ', k=len(transcript)))
    read_qual = prefix_qual + adapter_qual + bc_umi_qual + polyT_qual + transcript_qual
    
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
# Use relative paths from project root (where Nextflow is launched)
# Files are in test_data/longread/, so use relative path
FASTQ_REL="test_data/longread/$(basename "$FASTQ_FILE")"
cat > "$SAMPLESHEET" << EOF
sample,fastq,cell_count
TEST_SAMPLE,$FASTQ_REL,$NUM_CELLS
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
