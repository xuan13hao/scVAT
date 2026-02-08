#!/usr/bin/env python3

""" Extract barcode and UMI from Read ID header for short-read data.
    UMI-tools extract adds barcode and UMI to the Read ID in the format:
    @read_id_BC_UMI
    This script extracts this information and creates a TSV file.
"""

import argparse
import gzip
import re


def parse_args():
    """Parse the commandline arguments"""
    parser = argparse.ArgumentParser(
        description="Extract barcode and UMI from Read ID header"
    )
    parser.add_argument(
        "-i", "--input_fastq",
        required=True,
        type=str,
        help="Input FASTQ file (can be gzipped)"
    )
    parser.add_argument(
        "-o", "--output_tsv",
        required=True,
        type=str,
        help="Output TSV file with read_id, barcode, umi"
    )
    parser.add_argument(
        "--barcode_length",
        type=int,
        default=16,
        help="Length of cell barcode (default: 16)"
    )
    parser.add_argument(
        "--umi_length",
        type=int,
        default=12,
        help="Length of UMI (default: 12)"
    )
    args = parser.parse_args()
    return args


def extract_bc_umi_from_readid(input_fastq, output_tsv, barcode_length=16, umi_length=12):
    """Extract barcode and UMI from Read ID header
    
    UMI-tools extract adds barcode and UMI to Read ID in format:
    @read_id_BC_UMI
    
    Args:
        input_fastq (str): Path to input FASTQ file
        output_tsv (str): Path to output TSV file
        barcode_length (int): Expected length of barcode
        umi_length (int): Expected length of UMI
    """
    
    # Pattern to match Read ID with barcode and UMI: @read_id_BC_UMI
    # UMI-tools extract format: @read_id_BC_UMI
    pattern = re.compile(r'^@(.+?)_([ACGTN]{' + str(barcode_length) + r'})_([ACGTN]{' + str(umi_length) + r'})')
    
    # Open input file (handle gzipped or plain)
    if input_fastq.endswith('.gz'):
        fh_in = gzip.open(input_fastq, 'rt')
    else:
        fh_in = open(input_fastq, 'r')
    
    with fh_in, open(output_tsv, 'w') as fh_out:
        # Write header
        fh_out.write("read_id\tbc\tbc_qual\tumi\tumi_qual\n")
        
        line_count = 0
        for line in fh_in:
            line = line.strip()
            
            # Check if this is a Read ID line (starts with @)
            if line.startswith('@'):
                match = pattern.match(line)
                if match:
                    read_id = match.group(1)
                    barcode = match.group(2)
                    umi = match.group(3)
                    
                    # For short-read, we don't have quality scores in the Read ID
                    # Use placeholder or empty string
                    bc_qual = 'F' * barcode_length  # Placeholder quality
                    umi_qual = 'F' * umi_length     # Placeholder quality
                    
                    fh_out.write(f"{read_id}\t{barcode}\t{bc_qual}\t{umi}\t{umi_qual}\n")
                    line_count += 1
            
            # Skip sequence, +, and quality lines
            if line_count > 0 and not line.startswith('@') and not line.startswith('+'):
                continue
    
    print(f"Extracted {line_count} barcode/UMI pairs from Read IDs")


def main():
    """Main subroutine"""
    args = parse_args()
    extract_bc_umi_from_readid(
        args.input_fastq,
        args.output_tsv,
        args.barcode_length,
        args.umi_length
    )


if __name__ == "__main__":
    main()
