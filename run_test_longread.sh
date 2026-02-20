#!/bin/bash
nextflow run . \
    -profile singularity \
    -c conf/test_memory_limit.config \
    --input /home/xuan/scVAT/test_data/longread/samplesheet_longread.csv \
    --input_type long_read \
    --genome_fasta /home/xuan/scVAT/test_data/longread/chr21_ref.fa \
    --gtf https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/reference/chr21.gtf \
    --barcode_format 10X_3v3 \
    --quantifier isoquant \
    --skip_seurat \
    --skip_dedup \
    --skip_trimming \
    --skip_bam_nanocomp \
    --outdir test_output/longread_direct
nextflow run . -profile test_shortread_local,singularity --outdir test_output/shortread --input_type short_read 
