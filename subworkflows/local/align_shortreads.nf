//
// Performs alignment for short-read data using VAT
//

// SUBWORKFLOWS
include { BAM_SORT_STATS_SAMTOOLS                                     } from '../../subworkflows/nf-core/bam_sort_stats_samtools/main'
include { BAM_SORT_STATS_SAMTOOLS as BAM_SORT_STATS_SAMTOOLS_FILTERED } from '../../subworkflows/nf-core/bam_sort_stats_samtools/main'

// MODULES
include { VAT_INDEX                              } from '../../modules/local/vat_index'
include { VAT_ALIGN                              } from '../../modules/local/vat_align'
include { SAMTOOLS_VIEW as SAMTOOLS_FILTER_MAPPED } from '../../modules/nf-core/samtools/view'

include { RSEQC_READDISTRIBUTION } from '../../modules/nf-core/rseqc/readdistribution/main'
include { NANOCOMP               } from '../../modules/nf-core/nanocomp/main'


workflow ALIGN_SHORTREADS {
    take:
        fasta       // channel: [ val(meta), path(fasta) ]
        fai         // channel: [ val(meta), path(fai) ]
        gtf         // channel: [ val(meta), path(gtf) ]
        fastq       // channel: [ val(meta), path(fastq) ] - R2 (transcript) for short-read
        rseqc_bed   // channel: [ val(meta), path(rseqc_bed) ]

        skip_save_minimap2_index // bool: Skip saving the index (now VAT index)
        skip_qc                  // bool: Skip qc steps
        skip_rseqc               // bool: Skip RSeQC
        skip_bam_nanocomp        // bool: Skip Nanocomp
        alignment_mode           // str: Alignment mode for VAT ('splice' for genome, 'wgs' for transcriptome)
        long_read_mode           // bool: Whether to use --long flag (false for short reads)

    main:
        ch_versions = Channel.empty()
        //
        // VAT_INDEX
        //
        if (skip_save_minimap2_index) {
            VAT_INDEX ( fasta )
            ch_vat_ref = VAT_INDEX.out.index
            ch_versions = ch_versions.mix(VAT_INDEX.out.versions)
        } else {
            // If not saving index, use fasta directly (VAT can work with fasta or vatf)
            ch_vat_ref = fasta
        }

        //
        // VAT_ALIGN
        //

        VAT_ALIGN (
            fastq,
            ch_vat_ref,
            true,  // bam_format
            "bai", // bam_index_extension
            alignment_mode,  // alignment_mode: 'splice' for genome, 'wgs' for transcriptome
            long_read_mode   // long_read_mode: false for short reads
        )

        ch_versions = ch_versions.mix(VAT_ALIGN.out.versions)

        //
        // SUBWORKFLOW: BAM_SORT_STATS_SAMTOOLS
        // The subworkflow is called in both the VAT bams and filtered (mapped only) version
        BAM_SORT_STATS_SAMTOOLS ( VAT_ALIGN.out.bam, fasta )
        ch_versions = ch_versions.mix(BAM_SORT_STATS_SAMTOOLS.out.versions)

        // acquire only mapped reads from bam for downstream processing
        // NOTE: some QCs steps are performed on the full BAM
        SAMTOOLS_FILTER_MAPPED (
            BAM_SORT_STATS_SAMTOOLS.out.bam
                .join( BAM_SORT_STATS_SAMTOOLS.out.bai, by: 0 )
                .combine(["$projectDir/assets/dummy_file.txt"]),
            [[],[]],
            []
        )

        ch_vat_mapped_only_bam = SAMTOOLS_FILTER_MAPPED.out.bam
        ch_versions = ch_versions.mix(SAMTOOLS_FILTER_MAPPED.out.versions)

        BAM_SORT_STATS_SAMTOOLS_FILTERED (
            ch_vat_mapped_only_bam,
            fasta
        )

        ch_vat_filtered_sorted_bam = BAM_SORT_STATS_SAMTOOLS_FILTERED.out.bam
        ch_vat_filtered_sorted_bai = BAM_SORT_STATS_SAMTOOLS_FILTERED.out.bai
        ch_versions = ch_versions.mix(BAM_SORT_STATS_SAMTOOLS_FILTERED.out.versions)

        //
        // MODULE: RSeQC read distribution for BAM files (unfiltered for QC purposes)
        //
        ch_rseqc_read_dist = Channel.empty()
        if (!skip_qc && !skip_rseqc) {
            RSEQC_READDISTRIBUTION ( BAM_SORT_STATS_SAMTOOLS.out.bam, rseqc_bed )
            ch_rseqc_read_dist = RSEQC_READDISTRIBUTION.out.txt
            ch_versions = ch_versions.mix(RSEQC_READDISTRIBUTION.out.versions)
        }

        //
        // MODULE: NanoComp for BAM files (unfiltered for QC purposes)
        //
        ch_nanocomp_bam_html = Channel.empty()
        ch_nanocomp_bam_txt = Channel.empty()

        if (!skip_qc && !skip_bam_nanocomp) {

            NANOCOMP (
                BAM_SORT_STATS_SAMTOOLS.out.bam
                    .collect{it[1]}
                    .map{
                        [ [ 'id': 'nanocomp_bam.' ] , it ]
                    }
            )

            ch_nanocomp_bam_html = NANOCOMP.out.report_html
            ch_nanocomp_bam_txt = NANOCOMP.out.stats_txt
            ch_versions = ch_versions.mix( NANOCOMP.out.versions )
        }

    emit:
        versions = ch_versions

        // Bam and Bai
        sorted_bam = BAM_SORT_STATS_SAMTOOLS_FILTERED.out.bam
        sorted_bai = BAM_SORT_STATS_SAMTOOLS_FILTERED.out.bai

        // SAMtool stats from initial mapping
        stats = BAM_SORT_STATS_SAMTOOLS.out.stats
        flagstat = BAM_SORT_STATS_SAMTOOLS.out.flagstat
        idxstats = BAM_SORT_STATS_SAMTOOLS.out.idxstats

        // RSeQC stats
        rseqc_read_dist = ch_rseqc_read_dist

        // Nanoplot stats
        nanocomp_bam_html = ch_nanocomp_bam_html
        nanocomp_bam_txt = ch_nanocomp_bam_txt
}
