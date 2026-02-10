//
// Performs alignment for short-read (Illumina) single-cell RNA-seq data
//

// SUBWORKFLOWS
include { ALIGN_SHORTREADS } from '../../subworkflows/local/align_shortreads'
include { QUANTIFY_SCRNA_ISOQUANT } from '../../subworkflows/local/quantify_scrna_isoquant'
include { QUANTIFY_SCRNA_OARFISH  } from '../../subworkflows/local/quantify_scrna_oarfish'
include { DEDUP_UMIS              } from '../../subworkflows/local/dedup_umis'

// MODULES
include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_TAGGED } from '../../modules/nf-core/samtools/flagstat'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_TAGGED       } from '../../modules/nf-core/samtools/index'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_DEDUP        } from '../../modules/nf-core/samtools/index'
include { SAMTOOLS_VIEW as SAMTOOLS_FILTER_DEDUP        } from '../../modules/nf-core/samtools/view'

include { TAG_BARCODES } from '../../modules/local/tag_barcodes'


workflow PROCESS_SHORTREAD_SCRNA {
    take:
        fasta           // channel: [ val(meta), path(fasta) ]
        fai             // channel: [ val(meta), path(fai) ]
        gtf             // channel: [ val(meta), path(gtf) ]
        fastq_r1        // channel: [ val(meta), path(fastq_r1) ] - R1 contains barcode/UMI
        fastq_r2        // channel: [ val(meta), path(fastq_r2) ] - R2 contains transcript
        rseqc_bed       // channel: [ val(meta), path(rseqc_bed) ]
        whitelist       // channel: [ val(meta), path(whitelist) ] - UMI-tools whitelist
        quant_list      // list: List of quantifiers to use
        dedup_tool      // str: Name of deduplication tool to use (must be umitools for short-read)
        genome_aligned  // bool: Whether the bam is aligned to the genome or not
        fasta_delimiter // str: Delimiter character used in sequence id in fasta

        skip_save_minimap2_index // bool: Skip saving the index (now VAT index)
        skip_qc                  // bool: Skip qc steps
        skip_rseqc               // bool: Skip RSeQC
        skip_bam_nanocomp        // bool: Skip Nanocomp
        skip_seurat              // bool: Skip seurat qc steps
        skip_dedup               // bool: Skip deduplication (should be false for short-read)

    main:
        ch_versions = Channel.empty()

        //
        // SUBWORKFLOW: Align Short Read Data
        //

        // Determine alignment mode based on whether this is genome or transcriptome alignment
        // --splice is for RNA-seq reads (transcriptome), --wgs is for genomic reads (genome)
        alignment_mode = genome_aligned ? 'wgs' : 'splice'
        
        ALIGN_SHORTREADS(
            fasta,
            fai,
            gtf,
            fastq_r2,  // Use R2 (transcript) for alignment
            rseqc_bed,
            skip_save_minimap2_index,
            skip_qc,
            skip_rseqc,
            skip_bam_nanocomp,
            alignment_mode,  // 'splice' for genome, 'wgs' for transcriptome
            false             // long_read_mode: false for short reads
        )
        ch_versions = ch_versions.mix(ALIGN_SHORTREADS.out.versions)

        //
        // MODULE: Tag Barcodes (extract from Read ID for short-read)
        //

        TAG_BARCODES (
            ALIGN_SHORTREADS.out.sorted_bam
                .join( ALIGN_SHORTREADS.out.sorted_bai, by: 0 ),
            whitelist,
            true  // extract_from_readid: true for short-read
        )
        ch_versions = ch_versions.mix(TAG_BARCODES.out.versions)

        //
        // MODULE: Index Tagged Bam
        //
        SAMTOOLS_INDEX_TAGGED ( TAG_BARCODES.out.tagged_bam )
        ch_versions = ch_versions.mix(SAMTOOLS_INDEX_TAGGED.out.versions)

        //
        // MODULE: Flagstat Tagged Bam
        //
        SAMTOOLS_FLAGSTAT_TAGGED (
            TAG_BARCODES.out.tagged_bam
                .join( SAMTOOLS_INDEX_TAGGED.out.bai, by: [0])
        )
        ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT_TAGGED.out.versions)

        ch_bam = Channel.empty()
        ch_bai = Channel.empty()
        ch_flagstat = Channel.empty()
        ch_idxstats = Channel.empty()

        // For short-read, deduplication is mandatory (skip_dedup should be false)
        if (!skip_dedup) {
            // Force umitools for short-read data
            DEDUP_UMIS (
                fasta,
                fai,
                gtf,
                TAG_BARCODES.out.tagged_bam,
                SAMTOOLS_INDEX_TAGGED.out.bai,
                true, // Used to split the bam
                genome_aligned,
                'umitools',  // Force umitools for short-read
                fasta_delimiter
            )

            ch_bam = DEDUP_UMIS.out.dedup_bam
            ch_bai = DEDUP_UMIS.out.dedup_bai
            ch_flagstat = DEDUP_UMIS.out.dedup_flagstat
            ch_versions = DEDUP_UMIS.out.versions
        } else {
            // If dedup is skipped, warn but continue
            ch_bam = TAG_BARCODES.out.tagged_bam
            ch_bai = SAMTOOLS_INDEX_TAGGED.out.bai
            ch_flagstat = SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat
                .map{
                    meta, flagstat ->
                        id = ['id': meta.id]
                    [id, flagstat]
                }
        }
        //
        // SUBWORKFLOW: Quantify Features
        //

        ch_gene_qc_stats = Channel.empty()
        ch_transcript_qc_stats = Channel.empty()

        if (quant_list.contains("oarfish")) {
            QUANTIFY_SCRNA_OARFISH (
                ch_bam,
                ch_bai,
                ch_flagstat,
                fasta,
                skip_qc,
                skip_seurat
            )
            ch_versions = ch_versions.mix(QUANTIFY_SCRNA_OARFISH.out.versions)
            ch_transcript_qc_stats = QUANTIFY_SCRNA_OARFISH.out.transcript_qc_stats
        }

        if (quant_list.contains("isoquant")) {
            QUANTIFY_SCRNA_ISOQUANT (
                ch_bam,
                ch_bai,
                ch_flagstat,
                fasta,
                fai,
                gtf,
                skip_qc,
                skip_seurat
            )

            ch_versions = ch_versions.mix(QUANTIFY_SCRNA_ISOQUANT.out.versions)
            ch_gene_qc_stats = QUANTIFY_SCRNA_ISOQUANT.out.gene_qc_stats
            ch_transcript_qc_stats = QUANTIFY_SCRNA_ISOQUANT.out.transcript_qc_stats
        }

    emit:
        // Versions
        versions                 = ch_versions

        // VAT alignment results + qc's
        minimap_bam              = ALIGN_SHORTREADS.out.sorted_bam
        minimap_bai              = ALIGN_SHORTREADS.out.sorted_bai
        minimap_stats            = ALIGN_SHORTREADS.out.stats
        minimap_flagstat         = ALIGN_SHORTREADS.out.flagstat
        minimap_idxstats         = ALIGN_SHORTREADS.out.idxstats
        minimap_rseqc_read_dist  = ALIGN_SHORTREADS.out.rseqc_read_dist
        minimap_nanocomp_bam_txt = ALIGN_SHORTREADS.out.nanocomp_bam_txt

        // Barcode tagging results + qc's
        bc_tagged_bam            = TAG_BARCODES.out.tagged_bam
        bc_tagged_bai            = SAMTOOLS_INDEX_TAGGED.out.bai
        bc_tagged_flagstat       = SAMTOOLS_FLAGSTAT_TAGGED.out.flagstat

        // Deduplication results
        dedup_bam                = ch_bam
        dedup_bai                = ch_bai
        dedup_flagstat           = ch_flagstat
        dedup_idxstats           = ch_idxstats

        // Seurat QC Stats
        gene_qc_stats            = ch_gene_qc_stats
        transcript_qc_stats      = ch_transcript_qc_stats
}
